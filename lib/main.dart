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

enum EntryType { income, expense, saving, investment }
enum SavingCurrency { irr, usd }
enum InvestmentType { gold, stocks, crypto, other }

class FinanceEntry {
  final String id;
  final EntryType type;
  final DateTime date;
  final double amount;
  final String? note;
  final String? expenseCategory;
  final SavingCurrency? savingCurrency;
  final double? savingDelta;
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(entries: _entries, onRefresh: _refresh),
      AddEntryHub(onAdd: _addEntry),
      ExpensesPage(entries: _entries, onDelete: _delete),
      SavingsPage(entries: _entries),
      InvestmentsPage(entries: _entries, onDelete: _delete),
      GoalsPage(),
      const SettingsPage(),
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

/// ===== Add Hub (entry) =====
class AddEntryHub extends StatelessWidget {
  final void Function(FinanceEntry) onAdd;
  const AddEntryHub({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('افزودن تراکنش')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AddMenuTile(
            icon: Icons.south_west,
            title: 'افزودن هزینه',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AddExpensePage(onAdd: onAdd))),
          ),
          _AddMenuTile(
            icon: Icons.north_east,
            title: 'افزودن درآمد',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AddIncomePage(onAdd: onAdd))),
          ),
          _AddMenuTile(
            icon: Icons.savings_outlined,
            title: 'افزودن پس‌انداز',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AddSavingPage(onAdd: onAdd))),
          ),
          _AddMenuTile(
            icon: Icons.trending_up_outlined,
            title: 'افزودن سرمایه‌گذاری',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AddInvestmentPage(onAdd: onAdd))),
          ),
        ],
      ),
    );
  }
}

class _AddMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _AddMenuTile({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// ===== مشترک: اسکفولد فرم افزودن =====
class _AddScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final Widget? bottom; // برای فاصله FAB از پایین

  const _AddScaffold({
    required this.title,
    required this.children,
    required this.onSave,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...children,
          if (bottom != null) bottom!,
          const SizedBox(height: 88),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72), // کمی بالاتر از نوار پایین
        child: FloatingActionButton.large(
          onPressed: onSave,
          child: const Icon(Icons.save_outlined),
        ),
      ),
    );
  }
}

/// ===== داده‌های ثابت: دسته‌های هزینه =====
const List<String> kExpenseCategories = [
  'قبوض (آب/برق/گاز/اینترنت/موبایل)',
  'باشگاه - شهریه',
  'باشگاه - تغذیه/مکمل',
  'باشگاه - تجهیزات',
  'بیرون رفتن (عمدتاً شام)',
  'خرید وسایل خانه',
  'کمپ و تجهیزات',
  'هزینه ماشین (سوخت/سرویس/بیمه/...)',
  'مصرفی خانه (برنج/گوشت/مرغ/...)',
  'نظافت/بهداشت (شامپو/مایع‌ها/..)',
  'تعمیرات خانه/وسایل',
  'متفرقه',
];

/// ===== Add Expense =====
class AddExpensePage extends StatefulWidget {
  final void Function(FinanceEntry) onAdd;
  const AddExpensePage({super.key, required this.onAdd});
  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String? category;
  DateTime date = DateTime.now();

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AddScaffold(
      title: 'افزودن هزینه',
      onSave: () {
        final raw = amountCtrl.text.trim().replaceAll(',', '');
        final a = double.tryParse(raw);
        if (a == null || a <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مبلغ معتبر وارد کنید')),
          );
          return;
        }
        widget.onAdd(FinanceEntry(
          id: UniqueKey().toString(),
          type: EntryType.expense,
          date: date,
          amount: a,
          expenseCategory: category ?? 'متفرقه',
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        ));
        Navigator.pop(context);
      },
      children: [
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'مبلغ',
            border: OutlineInputBorder(),
            helperText: 'مثال: 250000',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: category,
          items: kExpenseCategories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => category = v),
          decoration: const InputDecoration(
            labelText: 'دسته هزینه',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'توضیحات (اختیاری)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('${date.year}/${date.month}/${date.day}'),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: date,
            );
            if (d != null) setState(() => date = d);
          },
        ),
      ],
    );
  }
}

/// ===== Add Income =====
class AddIncomePage extends StatefulWidget {
  final void Function(FinanceEntry) onAdd;
  const AddIncomePage({super.key, required this.onAdd});
  @override
  State<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends State<AddIncomePage> {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  DateTime date = DateTime.now();

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AddScaffold(
      title: 'افزودن درآمد',
      onSave: () {
        final raw = amountCtrl.text.trim().replaceAll(',', '');
        final a = double.tryParse(raw);
        if (a == null || a <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مبلغ معتبر وارد کنید')),
          );
          return;
        }
        widget.onAdd(FinanceEntry(
          id: UniqueKey().toString(),
          type: EntryType.income,
          date: date,
          amount: a,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        ));
        Navigator.pop(context);
      },
      children: [
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'مبلغ',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'توضیحات (اختیاری)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('${date.year}/${date.month}/${date.day}'),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: date,
            );
            if (d != null) setState(() => date = d);
          },
        ),
      ],
    );
  }
}

/// ===== Add Saving =====
class AddSavingPage extends StatefulWidget {
  final void Function(FinanceEntry) onAdd;
  const AddSavingPage({super.key, required this.onAdd});
  @override
  State<AddSavingPage> createState() => _AddSavingPageState();
}

class _AddSavingPageState extends State<AddSavingPage> {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  SavingCurrency currency = SavingCurrency.irr;
  DateTime date = DateTime.now();

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AddScaffold(
      title: 'افزودن پس‌انداز',
      onSave: () {
        final raw = amountCtrl.text.trim().replaceAll(',', '');
        final a = double.tryParse(raw);
        if (a == null || a == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('عدد معتبر (مثبت یا منفی) وارد کنید')),
          );
          return;
        }
        widget.onAdd(FinanceEntry(
          id: UniqueKey().toString(),
          type: EntryType.saving,
          date: date,
          amount: a.abs(),
          savingCurrency: currency,
          savingDelta: a, // مثبت=افزایش، منفی=برداشت
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        ));
        Navigator.pop(context);
      },
      children: [
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'مبلغ (+ برای افزودن / - برای برداشت)',
            border: OutlineInputBorder(),
            helperText: 'مثال: 500000 یا -200000',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<SavingCurrency>(
          value: currency,
          items: const [
            DropdownMenuItem(value: SavingCurrency.irr, child: Text('تومان')),
            DropdownMenuItem(value: SavingCurrency.usd, child: Text('دلار')),
          ],
          onChanged: (v) => setState(() => currency = v!),
          decoration: const InputDecoration(
            labelText: 'واحد',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'توضیحات (اختیاری)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('${date.year}/${date.month}/${date.day}'),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: date,
            );
            if (d != null) setState(() => date = d);
          },
        ),
      ],
    );
  }
}

/// ===== Add Investment =====
class AddInvestmentPage extends StatefulWidget {
  final void Function(FinanceEntry) onAdd;
  const AddInvestmentPage({super.key, required this.onAdd});
  @override
  State<AddInvestmentPage> createState() => _AddInvestmentPageState();
}

class _AddInvestmentPageState extends State<AddInvestmentPage> {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  InvestmentType iType = InvestmentType.gold;
  DateTime date = DateTime.now();

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AddScaffold(
      title: 'افزودن سرمایه‌گذاری',
      onSave: () {
        final raw = amountCtrl.text.trim().replaceAll(',', '');
        final a = double.tryParse(raw);
        if (a == null || a <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مبلغ معتبر وارد کنید')),
          );
          return;
        }
        widget.onAdd(FinanceEntry(
          id: UniqueKey().toString(),
          type: EntryType.investment,
          date: date,
          amount: a,
          investmentType: iType,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        ));
        Navigator.pop(context);
      },
      children: [
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'مبلغ',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<InvestmentType>(
          value: iType,
          items: const [
            DropdownMenuItem(value: InvestmentType.gold, child: Text('طلا')),
            DropdownMenuItem(value: InvestmentType.stocks, child: Text('بورس/صندوق')),
            DropdownMenuItem(value: InvestmentType.crypto, child: Text('کریپتو')),
            DropdownMenuItem(value: InvestmentType.other, child: Text('سایر (ملک/زمین/...)')),
          ],
          onChanged: (v) => setState(() => iType = v!),
          decoration: const InputDecoration(
            labelText: 'نوع سرمایه‌گذاری',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'توضیحات (اختیاری)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('${date.year}/${date.month}/${date.day}'),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: date,
            );
            if (d != null) setState(() => date = d);
          },
        ),
      ],
    );
  }
}
/// ===== ابزار: فرمت سه‌رقمی عدد =====
String fmt(double v) {
  final s = v.toStringAsFixed(0);
  final r = RegExp(r'\B(?=(\d{3})+(?!\d))');
  return s.replaceAllMapped(r, (m) => ',');
}

/// ===== ویجت‌های آماری کوچک =====
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
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(fmt(value), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final double value;
  const _MiniStat({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(fmt(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

/// ===== داشبورد =====
class DashboardPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  final Future<void> Function() onRefresh;
  const DashboardPage({super.key, required this.entries, required this.onRefresh});

  double get income => entries.where((e) => e.type == EntryType.income).fold(0.0, (p, e) => p + e.amount);
  double get expenses => entries.where((e) => e.type == EntryType.expense).fold(0.0, (p, e) => p + e.amount);
  double get savingIrr => entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr)
      .fold(0.0, (p, e) => p + (e.savingDelta ?? 0));
  double get savingUsd => entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd)
      .fold(0.0, (p, e) => p + (e.savingDelta ?? 0));
  double get investedTotal => entries.where((e) => e.type == EntryType.investment).fold(0.0, (p, e) => p + e.amount);

  @override
  Widget build(BuildContext context) {
    final balance = income - expenses;

    final expenseByCat = <String, double>{};
    for (final e in entries.where((e) => e.type == EntryType.expense)) {
      final k = e.expenseCategory ?? 'متفرقه';
      expenseByCat[k] = (expenseByCat[k] ?? 0) + e.amount;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(title: 'موجودی ساده', value: balance),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _MiniStat(title: 'درآمد', value: income)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat(title: 'هزینه', value: expenses)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _MiniStat(title: 'پس‌انداز (تومان)', value: savingIrr)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat(title: 'پس‌انداز (دلار)', value: savingUsd)),
          ]),
          const SizedBox(height: 8),
          _StatCard(title: 'جمع سرمایه‌گذاری', value: investedTotal),
          const SizedBox(height: 12),
          // نمودار دایره‌ای هزینه‌ها (به تفکیک دسته)
          PieCard(title: 'نمودار هزینه‌ها (دسته‌ها)', values: expenseByCat),
          const SizedBox(height: 16),
          const Text('آخرین تراکنش‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...entries.take(10).map((e) => _EntryTile(e)).toList(),
        ],
      ),
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
      if (e.note != null && e.note!.isNotEmpty) e.note!,
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(fmt(e.amount)),
      subtitle: Text(subtitle),
      trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
    );
  }
}

/// ===== صفحه هزینه‌ها =====
class ExpensesPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  final void Function(String id) onDelete;
  const ExpensesPage({super.key, required this.entries, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final expenses = entries.where((e) => e.type == EntryType.expense).toList();
    final byCat = <String, double>{};
    for (final e in expenses) {
      final k = e.expenseCategory ?? 'متفرقه';
      byCat[k] = (byCat[k] ?? 0) + e.amount;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('لیست هزینه‌ها')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          PieCard(title: 'نمودار هزینه‌ها (دسته‌ها)', values: byCat),
          const SizedBox(height: 8),
          ...expenses.map((e) => Dismissible(
                key: ValueKey(e.id),
                background: Container(color: Colors.redAccent),
                onDismissed: (_) => onDelete(e.id),
                child: ListTile(
                  leading: const Icon(Icons.south_west),
                  title: Text(fmt(e.amount)),
                  subtitle: Text(e.expenseCategory ?? 'متفرقه'),
                  trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
                ),
              )),
        ],
      ),
    );
  }
}

/// ===== صفحه پس‌انداز =====
class SavingsPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  const SavingsPage({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final irr = entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr);
    final usd = entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd);
    final irrSum = irr.fold(0.0, (p, e) => p + (e.savingDelta ?? 0));
    final usdSum = usd.fold(0.0, (p, e) => p + (e.savingDelta ?? 0));

    final values = {
      if (irrSum != 0) 'تومان': irrSum,
      if (usdSum != 0) 'دلار': usdSum,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('پس‌انداز')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(title: 'پس‌انداز تومان', value: irrSum),
          const SizedBox(height: 8),
          _StatCard(title: 'پس‌انداز دلار', value: usdSum),
          const SizedBox(height: 12),
          PieCard(title: 'نمودار پس‌انداز', values: values),
        ],
      ),
    );
  }
}

/// ===== صفحه سرمایه‌گذاری =====
class InvestmentsPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  final void Function(String id)?
    onDelete; // این خط را اضافه کن
  @override
  Widget build(BuildContext context) {
    final inv = entries.where((e) => e.type == EntryType.investment).toList();
    final byType = <String, double>{};
    String vt(InvestmentType t) => {
          InvestmentType.gold: 'طلا',
          InvestmentType.stocks: 'بورس/صندوق',2
          InvestmentType.crypto: 'کریپتو',
          InvestmentType.other: 'متفرقه',
        }[t]!;

    for (final e in inv) {
      final k = vt(e.investmentType ?? InvestmentType.other);
      byType[k] = (byType[k] ?? 0) + e.amount;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('سرمایه‌گذاری')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PieCard(title: 'نمودار سرمایه‌گذاری', values: byType),
          const SizedBox(height: 8),
          ...inv.map((e) => ListTile(
                leading: const Icon(Icons.trending_up),
                title: Text(fmt(e.amount)),
                subtitle: Text(vt(e.investmentType ?? InvestmentType.other)),
                trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
              )),
        ],
      ),
    );
  }
} 
/// ===== Goals (چک‌لیست اهداف خرید) =====
class Goal {
  final String id;
  final String title;
  final bool done;
  const Goal({required this.id, required this.title, required this.done});

  Goal copyWith({String? title, bool? done}) =>
      Goal(id: id, title: title ?? this.title, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
  factory Goal.fromJson(Map<String, dynamic> j) =>
      Goal(id: j['id'], title: j['title'], done: j['done'] ?? false);
}

class GoalsStore {
  static const _k = 'finance_goals';
  static Future<List<Goal>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Goal.fromJson).toList();
  }

  static Future<void> save(List<Goal> items) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<Goal> _items = [];
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _items = await GoalsStore.load();
    if (mounted) setState(() {});
  }

  Future<void> _addGoal(String title) async {
    final g = Goal(id: UniqueKey().toString(), title: title, done: false);
    _items = [..._items, g];
    await GoalsStore.save(_items);
    if (mounted) setState(() {});
  }

  Future<void> _toggle(String id, bool? v) async {
    _items = _items.map((g) => g.id == id ? g.copyWith(done: v ?? false) : g).toList();
    await GoalsStore.save(_items);
    if (mounted) setState(() {});
  }

  Future<void> _delete(String id) async {
    _items = _items.where((g) => g.id != id).toList();
    await GoalsStore.save(_items);
    if (mounted) setState(() {});
  }

  Future<void> _openAddDialog() async {
    _ctrl.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('افزودن هدف'),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثلاً: تلویزیون 55 اینچ'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('افزودن')),
        ],
      ),
    );
    if (ok == true && _ctrl.text.trim().isNotEmpty) {
      await _addGoal(_ctrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اهداف خرید')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('هنوز هدفی ثبت نشده. دکمه + پایین را بزنید')),
            ),
          ..._items.map((g) => Dismissible(
                key: ValueKey('goal_${g.id}'),
                background: Container(color: Colors.redAccent),
                onDismissed: (_) => _delete(g.id),
                child: CheckboxListTile(
                  key: ValueKey('checkbox_${g.id}'),
                  value: g.done,
                  onChanged: (v) => _toggle(g.id, v),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    g.title,
                    style: TextStyle(decoration: g.done ? TextDecoration.lineThrough : null),
                  ),
                ),
              )),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.large(
          onPressed: _openAddDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// ===== Settings =====
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('دسته‌بندی‌ها فعلاً ثابت هستند'),
            subtitle: Text('در نسخه بعدی امکان افزودن دسته سفارشی را اضافه می‌کنیم.'),
          ),
        ],
      ),
    );
  }
}

/// ===== PieCard: نمودار دایره‌ای ساده =====
class PieCard extends StatelessWidget {
  final String title;
  final Map<String, double> values; // label -> value

  const PieCard({super.key, required this.title, required this.values});

  Color _colorFor(int i) {
    const palette = [
      Color(0xFF26A69A),
      Color(0xFF42A5F5),
      Color(0xFFAB47BC),
      Color(0xFFFF7043),
      Color(0xFF7CB342),
      Color(0xFFFFCA28),
      Color(0xFF5C6BC0),
      Color(0xFFEF5350),
    ];
    return palette[i % palette.length];
  }

  List<PieChartSectionData> _sections() {
    final entries = values.entries.toList();
    final total = values.values.fold<double>(0, (p, v) => p + v);
    return List.generate(entries.length, (i) {
      final v = entries[i].value;
      return PieChartSectionData(
        value: v,
        title: total == 0 ? '' : '${(v / total * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: _colorFor(i),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = values.values.fold<double>(0, (p, v) => p + v);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: total <= 0
            ? const Text('داده‌ای برای نمایش نیست')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        sections: _sections(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: values.entries.toList().asMap().entries.map((entry) {
                      final i = entry.key;
                      final e = entry.value;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: _colorFor(i), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('${e.key}: ${fmt(e.value)}'),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
      ),
    );
  }
}
