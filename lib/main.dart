// Flutter: Minimal personal finance app for Android (family & friends)
// MVP features:
// - Add Income, Expense (with categories), Savings (IRR/USD), Investment (Gold/Stocks/Crypto/Other)
// - Shopping Goals (checklist with note)
// - Local persistence with SharedPreferences (JSON)
// - Dashboard totals
//
// Steps (already done in CI):
// - pubspec.yaml must include: shared_preferences: ^2.2.3  (and intl if خواستی)
// - flutter pub get

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Expense-only
  final String? expenseCategory;

  // Saving-only
  final SavingCurrency? savingCurrency; // irr/usd
  final double? savingDelta; // positive add, negative withdraw

  // Investment-only
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

// Goals model
class Goal {
  final String id;
  final String title;
  final String? note;
  final bool done;

  Goal({required this.id, required this.title, this.note, required this.done});

  Goal copyWith({String? title, String? note, bool? done}) => Goal(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'note': note, 'done': done};

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'],
        title: j['title'],
        note: j['note'],
        done: j['done'] == true,
      );
}

// ===== Persistence =====
class Store {
  static const _k = 'finance_entries';
  static const _kg = 'finance_goals';

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

  // Goals
  static Future<List<Goal>> loadGoals() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kg);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Goal.fromJson).toList();
  }

  static Future<void> saveGoals(List<Goal> goals) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(goals.map((g) => g.toJson()).toList());
    await sp.setString(_kg, raw);
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
  List<Goal> _goals = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadGoals();
  }

  Future<void> _refresh() async {
    final data = await Store.load();
    setState(() => _entries = data);
  }

  Future<void> _loadGoals() async {
    final gs = await Store.loadGoals();
    setState(() => _goals = gs);
  }

  void _addEntry(FinanceEntry e) async {
    final list = [..._entries, e]..sort((a, b) => b.date.compareTo(a.date));
    await Store.save(list);
    setState(() => _entries = list);
  }

  void _deleteEntry(String id) async {
    final list = _entries.where((e) => e.id != id).toList();
    await Store.save(list);
    setState(() => _entries = list);
  }

  Future<void> _addGoal(Goal g) async {
    final list = [..._goals, g];
    await Store.saveGoals(list);
    setState(() => _goals = list);
  }

  void _toggleGoal(String id, bool? v) async {
    final list =
        _goals.map((g) => g.id == id ? g.copyWith(done: v ?? false) : g).toList();
    await Store.saveGoals(list);
    setState(() => _goals = list);
  }

  void _deleteGoal(String id) async {
    final list = _goals.where((g) => g.id != id).toList();
    await Store.saveGoals(list);
    setState(() => _goals = list);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(entries: _entries, onRefresh: _refresh),
      AddEntryPage(onAdd: _addEntry),
      GoalsPage(
        goals: _goals,
        onAdd: (g) async => _addGoal(g),
        onDelete: _deleteGoal,
        onToggle: _toggleGoal,
      ),
      ExpensesPage(entries: _entries, onDelete: _deleteEntry),
      SavingsPage(entries: _entries),
      InvestmentsPage(entries: _entries),
      SettingsPage(onClear: () async {
        await Store.save([]);
        await Store.saveGoals([]);
        setState(() {
          _entries = [];
          _goals = [];
        });
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
          NavigationDestination(icon: Icon(Icons.checklist_rtl), label: 'اهداف'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'هزینه‌ها'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), label: 'پس‌انداز'),
          NavigationDestination(icon: Icon(Icons.trending_up_outlined), label: 'سرمایه‌گذاری'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
        ],
      ),
    );
  }
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

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(title: 'موجودی ساده', value: balance),
          const SizedBox(height: 8),
          _StatRow(items: [
            _MiniStat(title: 'درآمد', value: income),
            _MiniStat(title: 'هزینه', value: expenses),
          ]),
          const SizedBox(height: 8),
          _StatRow(items: [
            _MiniStat(title: 'پس‌انداز (تومان)', value: savingIrr),
            _MiniStat(title: 'پس‌انداز (دلار)', value: savingUsd),
          ]),
          const SizedBox(height: 8),
          _StatCard(title: 'جمع سرمایه‌گذاری', value: investedTotal),
          const SizedBox(height: 16),
          const Text('آخرین تراکنش‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...entries.take(10).map((e) => _EntryTile(e)).toList(),
        ],
      ),
    );
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
          Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                        Text(i.value.toStringAsFixed(0),
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
      title: Text(e.amount.toStringAsFixed(0)),
      subtitle: Text(subtitle.isEmpty ? (e.note ?? '') : subtitle),
      trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
    );
  }
}

// ===== Add Entry Page =====
class AddEntryPage extends StatefulWidget {
  final void Function(FinanceEntry) onAdd;
  const AddEntryPage({super.key, required this.onAdd});
  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  EntryType _type = EntryType.expense;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _expenseCategory;
  SavingCurrency _savingCurrency = SavingCurrency.irr;
  InvestmentType _investmentType = InvestmentType.gold;
  DateTime _date = DateTime.now();

  final expenseCategories = const [
    'قبوض (آب/برق/گاز/اینترنت/موبایل)',
    'باشگاه - شهریه',
    'باشگاه - تغذیه/مکمل (پروتئین/کراتین/...)',
    'باشگاه - تجهیزات',
    'بیرون رفتن (عمدتاً شام)',
    'خرید وسایل خانه (یخچال/تلویزیون/...)',
    'کمپ و تجهیزات (لامپ/جت فن/...)',
    'هزینه ماشین (سوخت/سرویس/بیمه/...)',
    'مصرفی خانه (برنج/گوشت/مرغ/...)',
    'نظافت/بهداشت (شامپو/...)',
    'تعمیرات خانه/وسایل',
    'متفرقه',
  ];

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ معتبر وارد کنید')),
      );
      return;
    }

    FinanceEntry e;
    switch (_type) {
      case EntryType.income:
        e = FinanceEntry(
          id: UniqueKey().toString(),
          type: EntryType.income,
          date: _date,
          amount: amount,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        break;
      case EntryType.expense:
        e = FinanceEntry(
          id: UniqueKey().toString(),
          type: EntryType.expense,
          date: _date,
          amount: amount,
          expenseCategory: _expenseCategory ?? 'متفرقه',
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        break;
      case EntryType.saving:
        e = FinanceEntry(
          id: UniqueKey().toString(),
          type: EntryType.saving,
          date: _date,
          amount: amount,
          savingCurrency: _savingCurrency,
          savingDelta: amount, // برای برداشت مقدار منفی وارد کن
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        break;
      case EntryType.investment:
        e = FinanceEntry(
          id: UniqueKey().toString(),
          type: EntryType.investment,
          date: _date,
          amount: amount,
          investmentType: _investmentType,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        break;
    }

    widget.onAdd(e);
    _amountCtrl.clear();
    _noteCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('افزودن تراکنش')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<EntryType>(
            segments: const [
              ButtonSegment(value: EntryType.expense, label: Text('هزینه')),
              ButtonSegment(value: EntryType.income, label: Text('درآمد')),
              ButtonSegment(value: EntryType.saving, label: Text('پس‌انداز')),
              ButtonSegment(value: EntryType.investment, label: Text('سرمایه‌گذاری')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'مبلغ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_type == EntryType.expense)
            DropdownButtonFormField<String>(
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
          if (_type == EntryType.saving) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<SavingCurrency>(
              value: _savingCurrency,
              items: const [
                DropdownMenuItem(value: SavingCurrency.irr, child: Text('تومان')),
                DropdownMenuItem(value: SavingCurrency.usd, child: Text('دلار')),
              ],
              onChanged: (v) => setState(() => _savingCurrency = v!),
              decoration: const InputDecoration(
                labelText: 'واحد پس‌انداز',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('نکته: برای برداشت می‌توانید مبلغ منفی وارد کنید (مثلاً -500000).'),
          ],
          if (_type == EntryType.investment) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<InvestmentType>(
              value: _investmentType,
              items: const [
                DropdownMenuItem(value: InvestmentType.gold, child: Text('طلا')),
                DropdownMenuItem(value: InvestmentType.stocks, child: Text('بورس/صندوق')),
                DropdownMenuItem(value: InvestmentType.crypto, child: Text('کریپتو')),
                DropdownMenuItem(value: InvestmentType.other, child: Text('متفرقه (ملک/زمین/...)')),
              ],
              onChanged: (v) => setState(() => _investmentType = v!),
              decoration: const InputDecoration(
                labelText: 'نوع سرمایه‌گذاری',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'توضیحات (اختیاری)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('${_date.year}/${_date.month}/${_date.day}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: _date,
                    );
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('ذخیره'),
                  onPressed: _submit,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

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
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('جمع به تفکیک دسته', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...byCat.entries
                      .map((e) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Text(e.key), Text(e.value.toStringAsFixed(0))],
                          ))
                      .toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...expenses.map((e) => Dismissible(
                key: ValueKey(e.id),
                background: Container(color: Colors.redAccent),
                onDismissed: (_) => onDelete(e.id),
                child: ListTile(
                  leading: const Icon(Icons.south_west),
                  title: Text(e.amount.toStringAsFixed(0)),
                  subtitle: Text(e.expenseCategory ?? 'متفرقه'),
                  trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
                ),
              )),
        ],
      ),
    );
  }
}

class SavingsPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  const SavingsPage({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final irr = entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr);
    final usd = entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd);
    final irrSum = irr.fold(0.0, (p, e) => p + (e.savingDelta ?? 0));
    final usdSum = usd.fold(0.0, (p, e) => p + (e.savingDelta ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('پس‌انداز')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(title: 'پس‌انداز تومان', value: irrSum),
          const SizedBox(height: 8),
          _StatCard(title: 'پس‌انداز دلار', value: usdSum),
        ],
      ),
    );
  }
}

class InvestmentsPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  const InvestmentsPage({super.key, required this.entries});
  @override
  Widget build(BuildContext context) {
    final inv = entries.where((e) => e.type == EntryType.investment).toList();
    final byType = <InvestmentType, double>{};
    for (final e in inv) {
      final k = e.investmentType ?? InvestmentType.other;
      byType[k] = (byType[k] ?? 0) + e.amount;
    }

    String vt(InvestmentType t) => {
          InvestmentType.gold: 'طلا',
          InvestmentType.stocks: 'بورس/صندوق',
          InvestmentType.crypto: 'کریپتو',
          InvestmentType.other: 'متفرقه (ملک/زمین/...)',
        }[t]!;

    return Scaffold(
      appBar: AppBar(title: const Text('سرمایه‌گذاری')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('جمع به تفکیک نوع', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...byType.entries
                      .map((e) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Text(vt(e.key)), Text(e.value.toStringAsFixed(0))],
                          ))
                      .toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...inv.map((e) => ListTile(
                leading: const Icon(Icons.trending_up),
                title: Text(e.amount.toStringAsFixed(0)),
                subtitle: Text(vt(e.investmentType ?? InvestmentType.other)),
                trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
              )),
        ],
      ),
    );
  }
}

// ===== Goals (Shopping targets) =====
class GoalsPage extends StatefulWidget {
  final List<Goal> goals;
  final Future<void> Function(Goal g) onAdd;
  final void Function(String id) onDelete;
  final void Function(String id, bool? done) onToggle;

  const GoalsPage({
    super.key,
    required this.goals,
    required this.onAdd,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  void _openAddDialog() async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('هدف خرید جدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'عنوان')),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'توضیح (اختیاری)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
        ],
      ),
    );
    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      final g = Goal(
        id: UniqueKey().toString(),
        title: titleCtrl.text.trim(),
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        done: false,
      );
      await widget.onAdd(g);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = widget.goals;
    return Scaffold(
      appBar: AppBar(title: const Text('اهداف خرید')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (goals.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text('فعلاً چیزی روی لیست نیست. روی + بزنید.')),
            )
          else
            ...goals.map((g) => Dismissible(
                  key: ValueKey(g.id),
                  background: Container(color: Colors.redAccent),
                  onDismissed: (_) => widget.onDelete(g.id),
                  child: CheckboxListTile(
                    value: g.done,
                    onChanged: (v) => widget.onToggle(g.id, v),
                    title: Text(
                      g.title,
                      style: TextStyle(
                        decoration: g.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: (g.note == null || g.note!.isEmpty) ? null : Text(g.note!),
                  ),
                )),
        ],
      ),
      // دکمه + کمی بالاتر از پایین
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.large(
          onPressed: _openAddDialog,
          child: const Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ===== Settings =====
class SettingsPage extends StatelessWidget {
  final Future<void> Function()? onClear;
  const SettingsPage({super.key, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('دسته‌بندی‌ها فعلاً ثابت هستند'),
            subtitle: const Text('در نسخه بعدی می‌توانید دسته جدید اضافه کنید.'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_forever),
            label: const Text('حذف همه داده‌ها'),
          ),
        ],
      ),
    );
  }
}
