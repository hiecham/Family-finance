// Family Finance — full single-file app (stable IDs + safe keys)
// Features: income/expense/saving/investment, per-item delete,
// goals checklist (independent state), number formatting, pie charts,
// local persistence via SharedPreferences.

import 'dart:convert';
import 'dart:math';
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

/// ==== Models & enums ====
enum EntryType { income, expense, saving, investment }
enum SavingCurrency { irr, usd }
enum InvestmentType { gold, stocks, crypto, other }

class FinanceEntry {
  final String id;
  final EntryType type;
  final DateTime date;
  final double amount;
  final String? note;

  // expense
  final String? expenseCategory;
  // saving
  final SavingCurrency? savingCurrency;
  final double? savingDelta;
  // investment
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
        savingDelta:
            j['savingDelta'] == null ? null : (j['savingDelta'] as num).toDouble(),
        investmentType: j['investmentType'] == null
            ? null
            : InvestmentType.values
                .firstWhere((e) => e.name == j['investmentType']),
      );
}

/// ==== Persistence ====
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

/// ==== number format (3-digit grouping) — keep ONLY this one! ====
String fmt(double v) {
  final s = v.toStringAsFixed(0);
  final r = RegExp(r'\B(?=(\d{3})+(?!\d))');
  return s.replaceAllMapped(r, (m) => ',');
}

/// ==== ID generator (stable, unique) ====
final Random _rand = Random();
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toString()}-${_rand.nextInt(0x7fffffff)}';

/// ==== Root with bottom navigation ====
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
    final list = [..._entries, e]..sort((a, b) => b.date.compareTo(a.date));
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
      DashboardPage(entries: _entries, onRefresh: _refresh, onDelete: _delete),
      AddEntryPage(onAdd: _addEntry),
      ExpensesPage(entries: _entries, onDelete: _delete),
      SavingsPage(entries: _entries),
      InvestmentsPage(entries: _entries, onDelete: _delete),
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

/// ==== Dashboard ====
class DashboardPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  final Future<void> Function() onRefresh;
  final void Function(String id) onDelete;
  const DashboardPage({super.key, required this.entries, required this.onRefresh, required this.onDelete});

  double get income => entries.where((e) => e.type == EntryType.income).fold(0.0, (p, e) => p + e.amount);
  double get expenses => entries.where((e) => e.type == EntryType.expense).fold(0.0, (p, e) => p + e.amount);
  double get savingIrr => entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr).fold(0.0, (p, e) => p + (e.savingDelta ?? 0));
  double get savingUsd => entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd).fold(0.0, (p, e) => p + (e.savingDelta ?? 0));
  double get investedTotal => entries.where((e) => e.type == EntryType.investment).fold(0.0, (p, e) => p + e.amount);

  Map<String, double> get _expenseByCat {
    final by = <String, double>{};
    for (final e in entries.where((e) => e.type == EntryType.expense)) {
      final k = e.expenseCategory ?? 'متفرقه';
      by[k] = (by[k] ?? 0) + e.amount;
    }
    return by;
  }

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
          const SizedBox(height: 12),
          if (_expenseByCat.isNotEmpty) PieCard(title: 'نمودار هزینه‌ها', values: _expenseByCat),
          const SizedBox(height: 16),
          const Text('آخرین تراکنش‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...entries.take(10).map((e) => Dismissible(
                key: ValueKey('dash_${e.id}'), // کلید یکتا و پایدار
                background: Container(color: Colors.redAccent),
                onDismissed: (_) => onDelete(e.id),
                child: _EntryTile(e),
              )),
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
        padding: const EdgeInsets.all(16),
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
                        Text(fmt(i.value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      if (e.note != null && e.note!.isNotEmpty) e.note!,
    ].join(' · ');

    return ListTile(
      key: ValueKey('tile_${e.id}'), // جلوگیری از reuse اشتباه
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(fmt(e.amount)),
      subtitle: Text(subtitle),
      trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
    );
  }
}

/// ==== Add Entry Page (one screen for all types) ====
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
    'باشگاه - تغذیه/مکمل',
    'باشگاه - تجهیزات',
    'بیرون رفتن (شام/کافه)',
    'خرید وسایل خانه',
    'کمپ و تجهیزات',
    'هزینه ماشین (سوخت/سرویس/بیمه)',
    'مصرفی خانه (برنج/گوشت/مرغ/...)',
    'نظافت/بهداشت',
    'تعمیرات',
    'متفرقه',
  ];

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ معتبر وارد کنید')));
      return;
    }

    FinanceEntry e;
    switch (_type) {
      case EntryType.income:
        e = FinanceEntry(
          id: newId(),
          type: EntryType.income,
          date: _date,
          amount: amount,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        break;
      case EntryType.expense:
        e = FinanceEntry(
          id: newId(),
          type: EntryType.expense,
          date: _date,
          amount: amount,
          expenseCategory: _expenseCategory ?? 'متفرقه',
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        break;
      case EntryType.saving:
        e = FinanceEntry(
          id: newId(),
          type: EntryType.saving,
          date: _date,
          amount: amount,
          savingCurrency: _savingCurrency,
          savingDelta: amount, // برداشت = مبلغ منفی
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        break;
      case EntryType.investment:
        e = FinanceEntry(
          id: newId(),
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
            decoration: const InputDecoration(labelText: 'مبلغ', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (_type == EntryType.expense)
            DropdownButtonFormField<String>(
              value: _expenseCategory,
              items: expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _expenseCategory = v),
              decoration: const InputDecoration(labelText: 'دسته هزینه', border: OutlineInputBorder()),
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
              decoration: const InputDecoration(labelText: 'واحد پس‌انداز', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            const Text('نکته: برای برداشت از پس‌انداز، مبلغ منفی وارد کنید (مثلاً -500000).'),
          ],
          if (_type == EntryType.investment) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<InvestmentType>(
              value: _investmentType,
              items: const [
                DropdownMenuItem(value: InvestmentType.gold, child: Text('طلا')),
                DropdownMenuItem(value: InvestmentType.stocks, child: Text('بورس/صندوق')),
                DropdownMenuItem(value: InvestmentType.crypto, child: Text('کریپتو')),
                DropdownMenuItem(value: InvestmentType.other, child: Text('متفرقه')),
              ],
              onChanged: (v) => setState(() => _investmentType = v!),
              decoration: const InputDecoration(labelText: 'نوع سرمایه‌گذاری', border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)', border: OutlineInputBorder()),
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

/// ==== Expenses ====
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
          if (byCat.isNotEmpty)
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
                    ...byCat.entries.map((e) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text(e.key), Text(fmt(e.value))],
                        )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (byCat.isNotEmpty) PieCard(title: 'نمودار هزینه‌ها', values: byCat),
          const SizedBox(height: 8),
          ...expenses.map((e) => Dismissible(
                key: ValueKey('exp_${e.id}'),
                background: Container(color: Colors.redAccent),
                onDismissed: (_) => onDelete(e.id),
                child: ListTile(
                  key: ValueKey('tile_exp_${e.id}'),
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

/// ==== Savings ====
class SavingsPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  const SavingsPage({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final irr = entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr);
    final usd = entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd);
    final irrSum = irr.fold(0.0, (p, e) => p + (e.savingDelta ?? 0));
    final usdSum = usd.fold(0.0, (p, e) => p + (e.savingDelta ?? 0));

    final values = <String, double>{
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
          if (values.isNotEmpty) PieCard(title: 'نمودار پس‌انداز', values: values),
        ],
      ),
    );
  }
}

/// ==== Investments (with delete) ====
class InvestmentsPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  final void Function(String id) onDelete;

  const InvestmentsPage({
    super.key,
    required this.entries,
    required this.onDelete,
  });

  String _vt(InvestmentType t) => {
        InvestmentType.gold: 'طلا',
        InvestmentType.stocks: 'بورس/صندوق',
        InvestmentType.crypto: 'کریپتو',
        InvestmentType.other: 'متفرقه',
      }[t]!;

  @override
  Widget build(BuildContext context) {
    final inv = entries.where((e) => e.type == EntryType.investment).toList();

    final byType = <InvestmentType, double>{};
    for (final e in inv) {
      final k = e.investmentType ?? InvestmentType.other;
      byType[k] = (byType[k] ?? 0) + e.amount;
    }

    final pieValues = <String, double>{
      for (final e in byType.entries) _vt(e.key): e.value,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('سرمایه‌گذاری')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (byType.isNotEmpty)
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
                    ...byType.entries.map((e) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text(_vt(e.key)), Text(fmt(e.value))],
                        )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (pieValues.isNotEmpty) PieCard(title: 'نمودار سرمایه‌گذاری', values: pieValues),
          const SizedBox(height: 8),
          ...inv.map(
            (e) => Dismissible(
              key: ValueKey('inv_${e.id}'),
              background: Container(color: Colors.redAccent),
              onDismissed: (_) => onDelete(e.id),
              child: ListTile(
                key: ValueKey('tile_inv_${e.id}'),
                leading: const Icon(Icons.trending_up),
                title: Text(fmt(e.amount)),
                subtitle: Text(_vt(e.investmentType ?? InvestmentType.other)),
                trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ==== Goals (Checklist) ====
// ثابت: کلیدها/IDهای پایدار برای جلوگیری از سرایت تیک‌ها
class Goal {
  final String id;
  final String title;
  final bool done;
  Goal({required this.id, required this.title, required this.done});

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

  static Future<void> save(List<Goal> goals) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(goals.map((g) => g.toJson()).toList()));
  }
}

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<Goal> _goals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _goals = await GoalsStore.load();
    setState(() {});
  }

  Future<void> _addGoal() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (cxt) => AlertDialog(
        title: const Text('افزودن هدف'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'مثلاً: خرید تلویزیون')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(cxt, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(cxt, true), child: const Text('ثبت')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      setState(() => _goals = [
            ..._goals,
            Goal(id: newId(), title: c.text.trim(), done: false),
          ]);
      await GoalsStore.save(_goals);
    }
  }

  Future<void> _toggle(String id, bool v) async {
    setState(() {
      _goals = _goals
          .map((g) => g.id == id ? Goal(id: g.id, title: g.title, done: v) : g)
          .toList();
    });
    await GoalsStore.save(_goals);
  }

  Future<void> _delete(String id) async {
    setState(() => _goals = _goals.where((g) => g.id != id).toList());
    await GoalsStore.save(_goals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اهداف خرید')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          if (_goals.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text('هنوز هدفی ثبت نشده. دکمه + پایین را بزنید.')),
            )
          else
            ..._goals.map((g) => Dismissible(
                  key: ValueKey('goal_${g.id}'),
                  background: Container(color: Colors.redAccent),
                  onDismissed: (_) => _delete(g.id),
                  child: CheckboxListTile(
                    key: ValueKey('goalcb_${g.id}'), // کلید مستقل برای جلوگیری از سرایت state
                    value: g.done,
                    onChanged: (v) => _toggle(g.id, v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      g.title,
                      style: TextStyle(
                        decoration: g.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: g.done ? const Text('انجام شد!') : null,
                  ),
                )),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.large(
          onPressed: _addGoal,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// ==== Settings ====
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
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('دسته‌بندی‌ها فعلاً ثابت هستند'),
            subtitle: Text('در نسخه بعدی می‌توانید دسته جدید اضافه کنید.'),
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

/// ==== PieCard (fl_chart) ====
class PieCard extends StatelessWidget {
  final String title;
  final Map<String, double> values;
  const PieCard({super.key, required this.title, required this.values});

  Color _colorFor(int i) {
    const palette = [
      Color(0xFF26A69A),
      Color(0xFF42A5F5),
      Color(0xFFAB47BC),
      Color(0xFF7CB342),
      Color(0xFFFF7043),
      Color(0xFFFFCA28),
      Color(0xFF5C6BC0),
      Color(0xFFEF5350),
    ];
    return palette[i % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList();
    final total = values.values.fold<double>(0, (p, v) => p + v);

    List<PieChartSectionData> _sections() {
      if (entries.isEmpty) return [];
      return List.generate(entries.length, (i) {
        final v = entries[i].value;
        final pct = total == 0 ? 0 : (v / total * 100).toStringAsFixed(0);
        return PieChartSectionData(
          value: v,
          title: total == 0 ? '' : '$pct%',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          color: _colorFor(i),
        );
      });
    }

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
                    child: PieChart(PieChartData(
                      sections: _sections(),
                      centerSpaceRadius: 32,
                      sectionsSpace: 2,
                    )),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (int i = 0; i < entries.length; i++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: _colorFor(i), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('${entries[i].key}: ${fmt(entries[i].value)}'),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
