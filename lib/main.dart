import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'Roboto',
      ),
      home: const RootPage(),
    );
  }
}

// ===== Models =====

enum EntryType { income, expense, saving, investment }
enum SavingCurrency { irr, usd }
enum InvestmentType { gold, stocks, crypto, other }

class FinanceEntry {
  final String id;
  final EntryType type;
  final DateTime date;
  final double amount;
  final String? note;

  // Expense
  final String? expenseCategory;

  // Saving
  final SavingCurrency? savingCurrency;
  final double? savingDelta;

  // Investment
  final InvestmentType? investmentType;

  FinanceEntry({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    this.note,
    this.expenseCategory,
    this.savingCurrency,
    this.savingDelta,
    this.investmentType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'date': date.toIso8601String(),
        'amount': amount,
        'note': note,
        'expenseCategory': expenseCategory,
        'savingCurrency': savingCurrency?.name,
        'savingDelta': savingDelta,
        'investmentType': investmentType?.name,
      };

  factory FinanceEntry.fromJson(Map<String, dynamic> j) => FinanceEntry(
        id: j['id'],
        type: EntryType.values.firstWhere((e) => e.name == j['type']),
        date: DateTime.parse(j['date']),
        amount: (j['amount'] as num).toDouble(),
        note: j['note'],
        expenseCategory: j['expenseCategory'],
        savingCurrency: j['savingCurrency'] == null
            ? null
            : SavingCurrency.values
                .firstWhere((e) => e.name == j['savingCurrency']),
        savingDelta: j['savingDelta'] == null
            ? null
            : (j['savingDelta'] as num).toDouble(),
        investmentType: j['investmentType'] == null
            ? null
            : InvestmentType.values
                .firstWhere((e) => e.name == j['investmentType']),
      );
}

// ===== Persistence =====
class Store {
  static const _k = 'finance_entries';

  static Future<List<FinanceEntry>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(FinanceEntry.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> save(List<FinanceEntry> entries) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await sp.setString(_k, raw);
  }
}

// ===== Root (Bottom Nav) =====
class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _idx = 0;
  List<FinanceEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final data = await Store.load();
    setState(() => _entries = data);
  }

  void _addEntry(FinanceEntry e) async {
    final list = [..._entries, e];
    list.sort((a, b) => b.date.compareTo(a.date));
    await Store.save(list);
    setState(() => _entries = list);
  }

  void _delete(String id) async {
    final list = _entries.where((e) => e.id != id).toList();
    await Store.save(list);
    setState(() => _entries = list);
  }

  void _edit(FinanceEntry updated) async {
    final list = _entries.map((e) => e.id == updated.id ? updated : e).toList();
    await Store.save(list);
    setState(() => _entries = list);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(entries: _entries, onRefresh: _refresh),
      AddEntryHub(onAdd: _addEntry),
      ExpensesPage(entries: _entries, onDelete: _delete),
      SavingsPage(entries: _entries),
      InvestmentsPage(entries: _entries, onDelete: _delete, onEdit: _edit),
      GoalsPage(),
      SettingsPage(onClear: () async {
        await Store.save([]);
        setState(() => _entries = []);
      }),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_idx]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'داشبورد'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'افزودن'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'هزینه‌ها'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), label: 'پس‌انداز'),
          NavigationDestination(icon: Icon(Icons.trending_up_outlined), label: 'سرمایه‌گذاری'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: 'اهداف'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
        ],
      ),
    );
  }
}

// ===== Utils =====
String fmt(double v) {
  final s = v.toStringAsFixed(0);
  final r = RegExp(r'\B(?=(\d{3})+(?!\d))');
  return s.replaceAllMapped(r, (m) => ',');
}

// ===== Pages =====

class DashboardPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  final Future<void> Function() onRefresh;
  const DashboardPage({super.key, required this.entries, required this.onRefresh});

  double get income => entries
      .where((e) => e.type == EntryType.income)
      .fold(0.0, (p, e) => p + e.amount);

  double get expenses => entries
      .where((e) => e.type == EntryType.expense)
      .fold(0.0, (p, e) => p + e.amount);

  double get savingIrr => entries
      .where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr)
      .fold(0.0, (p, e) => p + (e.savingDelta ?? 0));

  double get savingUsd => entries
      .where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd)
      .fold(0.0, (p, e) => p + (e.savingDelta ?? 0));

  double get investedTotal => entries
      .where((e) => e.type == EntryType.investment)
      .fold(0.0, (p, e) => p + e.amount);

  @override
  Widget build(BuildContext context) {
    final balance = income - expenses;

    final expenseByCat = <String, double>{};
    for (final e in entries.where((e) => e.type == EntryType.expense)) {
      final k = e.expenseCategory ?? 'متفرقه';
      expenseByCat[k] = (expenseByCat[k] ?? 0) + e.amount;
    }

    final incomeMap = {'درآمد': income};
    final expenseMap = expenseByCat.isEmpty ? {'هزینه': expenses} : expenseByCat;
    final savingMap = {
      'تومان': savingIrr,
      'دلار': savingUsd,
    };
    final investMap = _sumInvestMap(entries);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(title: 'موجودی ساده', value: balance),
          const SizedBox(height: 8),
          _StatRow(
            items: [
              _MiniStat(title: 'درآمد', value: income),
              _MiniStat(title: 'هزینه', value: expenses),
            ],
          ),
          const SizedBox(height: 8),
          _StatRow(
            items: [
              _MiniStat(title: 'پس‌انداز (تومان)', value: savingIrr),
              _MiniStat(title: 'پس‌انداز (دلار)', value: savingUsd),
            ],
          ),
          const SizedBox(height: 12),
          _PieCard(title: 'نمودار هزینه‌ها', values: expenseMap),
          const SizedBox(height: 12),
          _PieCard(title: 'نمودار درآمد', values: incomeMap),
          const SizedBox(height: 12),
          _PieCard(title: 'نمودار پس‌انداز', values: savingMap),
          const SizedBox(height: 12),
          _PieCard(title: 'نمودار سرمایه‌گذاری', values: investMap),
          const SizedBox(height: 16),
          const Text('آخرین تراکنش‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...entries.take(10).map((e) => _EntryTile(e)).toList(),
        ],
      ),
    );
  }

  static Map<String, double> _sumInvestMap(List<FinanceEntry> entries) {
    final byType = <InvestmentType, double>{};
    for (final e in entries.where((e) => e.type == EntryType.investment)) {
      final k = e.investmentType ?? InvestmentType.other;
      byType[k] = (byType[k] ?? 0) + e.amount;
    }
    String vt(InvestmentType t) => {
          InvestmentType.gold: 'طلا',
          InvestmentType.stocks: 'بورس/صندوق',
          InvestmentType.crypto: 'کریپتو',
          InvestmentType.other: 'سایر',
        }[t]!;
    return {for (final e in byType.entries) vt(e.key): e.value};
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double value;
  const _StatCard({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(fmt(value), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _MiniStat {
  final String title;
  final double value;
  const _MiniStat({required this.title, required this.value});
}

class _StatRow extends StatelessWidget {
  final List<_MiniStat> items;
  const _StatRow({required this.items});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map((i) => Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(fmt(i.value),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final FinanceEntry e;
  const _EntryTile(this.e);
  @override
  Widget build(BuildContext context) {
    final icon = switch (e.type) {
      EntryType.income => Icons.north_east,
      EntryType.expense => Icons.south_west,
      EntryType.saving => Icons.savings,
      EntryType.investment => Icons.trending_up,
    };
    final subtitle = [
      if (e.expenseCategory != null) e.expenseCategory!,
      if (e.savingCurrency != null) (e.savingCurrency == SavingCurrency.irr ? 'تومان' : 'دلار'),
      if (e.investmentType != null)
        {
          InvestmentType.gold: 'طلا',
          InvestmentType.stocks: 'بورس/صندوق',
          InvestmentType.crypto: 'کریپتو',
          InvestmentType.other: 'متفرقه',
        }[e.investmentType]!,
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(fmt(e.amount)),
      subtitle: Text(subtitle.isEmpty ? (e.note ?? '') : subtitle),
      trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
    );
  }
}

// ===== Add Hub (splitted screens) =====
class AddEntryHub extends StatelessWidget {
  final void Function(FinanceEntry) onAdd;
  const AddEntryHub({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('افزودن')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AddCard(
            icon: Icons.south_west,
            title: 'افزودن هزینه',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AddExpensePage(onAdd: onAdd))),
          ),
          _AddCard(
            icon: Icons.north_east,
            title: 'افزودن درآمد',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AddIncomePage(onAdd: onAdd))),
          ),
          _AddCard(
            icon: Icons.savings_outlined,
            title: 'افزودن پس‌انداز',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AddSavingPage(onAdd: onAdd))),
          ),
          _AddCard(
            icon: Icons.trending_up,
            title: 'افزودن سرمایه‌گذاری',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AddInvestmentPage(onAdd: onAdd))),
          ),
        ],
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _AddCard({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}

// ===== Add pages (Expense/Income/Saving/Investment) =====

class AddExpensePage extends StatefulWidget {
  final void Function(FinanceEntry) onAdd;
  const AddExpensePage({super.key, required this.onAdd});
  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _expenseCategory;

  final expenseCategories = const [
    'قبوض (آب/برق/گاز/اینترنت/موبایل)',
    'باشگاه - شهریه',
    'باشگاه - تغذیه/مکمل',
    'باشگاه - تجهیزات',
    'بیرون رفتن (شام)',
    'خرید وسایل خانه',
    'کمپ و تجهیزات',
    'هزینه ماشین',
    'مصرفی خانه (برنج/گوشت/مرغ/...)',
    'نظافت/بهداشت',
    'تعمیرات خانه/وسایل',
    'متفرقه',
  ];

  void _submit() {
    final a = double.tryParse(_amountCtrl.text.trim());
    if (a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ معتبر وارد کنید')),
      );
      return;
    }
    widget.onAdd(FinanceEntry(
      id: UniqueKey().toString(),
      type: EntryType.expense,
      date: _date,
      amount: a,
      expenseCategory: _expenseCategory ?? 'متفرقه',
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _AddScaffold(
      title: 'ثبت هزینه',
      amountCtrl: _amountCtrl,
      noteCtrl: _noteCtrl,
      date: _date,
      onPickDate: (d) => setState(() => _date = d),
      extra: DropdownButtonFormField<String>(
        value: _expenseCategory,
        items: expenseCategories
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => setState(() => _expenseCategory = v),
        decoration: const InputDecoration(
          labelText: 'دسته هزینه',
          border: OutlineInputBorder(),
        ),
      ),
      onSubmit: _submit,
    );
  }
}

class AddIncomePage extends StatefulWidget {
  final void Function(FinanceEntry) onAdd;
  const AddIncomePage({super.key, required this.onAdd});
  @override
  State<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends State<AddIncomePage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  void _submit() {
    final a = double.tryParse(_amountCtrl.text.trim());
    if (a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ معتبر وارد کنید')),
      );
      return;
    }
    widget.onAdd(FinanceEntry(
      id: UniqueKey().toString(),
      type: EntryType.income,
      date: _date,
      amount: a,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _AddScaffold(
      title: 'ثبت درآمد',
      amountCtrl: _amountCtrl,
      noteCtrl: _noteCtrl,
      date: _date,
      onPickDate: (d) => setState(() => _date = d),
      onSubmit: _submit,
    );
  }
}

class AddSavingPage extends StatefulWidget {
  final void Function(FinanceEntry) onAdd;
  const AddSavingPage({super.key, required this.onAdd});
  @override
  State<AddSavingPage> createState() => _AddSavingPageState();
}

class _AddSavingPageState extends State<AddSavingPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  SavingCurrency _currency = SavingCurrency.irr;

  void _submit() {
    final a = double.tryParse(_amountCtrl.text.trim());
    if (a == null || a == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ معتبر وارد کنید (مثبت برای واریز، منفی برای برداشت)')),
      );
      return;
    }
    widget.onAdd(FinanceEntry(
      id: UniqueKey().toString(),
      type: EntryType.saving,
      date: _date,
      amount: a.abs(),
      savingCurrency: _currency,
      savingDelta: a, // منفی = برداشت
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _AddScaffold(
      title: 'ثبت پس‌انداز',
      amountCtrl: _amountCtrl,
      noteCtrl: _noteCtrl,
      date: _date,
      onPickDate: (d) => setState(() => _date = d),
      extra: DropdownButtonFormField<SavingCurrency>(
        value: _currency,
        items: const [
          DropdownMenuItem(value: SavingCurrency.irr, child: Text('تومان')),
          DropdownMenuItem(value: SavingCurrency.usd, child: Text('دلار')),
        ],
        onChanged: (v) => setState(() => _currency = v!),
        decoration: const InputDecoration(
          labelText: 'واحد پس‌انداز',
          border: OutlineInputBorder(),
        ),
      ),
      onSubmit: _submit,
    );
  }
}

class AddInvestmentPage extends StatefulWidget {
  final void Function(FinanceEntry) onAdd;
  const AddInvestmentPage({super.key, required this.onAdd});
  @override
  State<AddInvestmentPage> createState() => _AddInvestmentPageState();
}

class _AddInvestmentPageState extends State<AddInvestmentPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  InvestmentType _type = InvestmentType.gold;

  void _submit() {
    final a = double.tryParse(_amountCtrl.text.trim());
    if (a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ معتبر وارد کنید')),
      );
      return;
    }
    widget.onAdd(FinanceEntry(
      id: UniqueKey().toString(),
      type: EntryType.investment,
      date: _date,
      amount: a,
      investmentType: _type,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _AddScaffold(
      title: 'ثبت سرمایه‌گذاری',
      amountCtrl: _amountCtrl,
