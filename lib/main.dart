// Flutter personal finance (Android) — Full main.dart (fixed braces) // Features: income/expense/saving/investment, goals checklist, local storage, // number formatting with Intl, pie charts with fl_chart, delete (swipe), edit investments.

import 'dart:convert'; import 'package:flutter/material.dart'; import 'package:shared_preferences/shared_preferences.dart'; import 'package:intl/intl.dart'; import 'package:fl_chart/fl_chart.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const FinanceApp()); }

class FinanceApp extends StatelessWidget { const FinanceApp({super.key}); @override Widget build(BuildContext context) { return MaterialApp( title: 'Family Finance', debugShowCheckedModeBanner: false, theme: ThemeData( useMaterial3: true, colorSchemeSeed: Colors.teal, fontFamily: 'Roboto', ), home: const RootPage(), ); } }

/// ===== Helpers ===== final _nf = NumberFormat.decimalPattern('en'); // e.g., 100,000 String fmt(num v) => _nf.format(v.round());

/// ===== Models ===== enum EntryType { income, expense, saving, investment } enum SavingCurrency { irr, usd } enum InvestmentType { gold, stocks, crypto, other }

class FinanceEntry { final String id; final EntryType type; final DateTime date; final double amount; final String? note; // if income => source final String? expenseCategory; // Expense final SavingCurrency? savingCurrency; // Saving final double? savingDelta; // Saving final InvestmentType? investmentType; // Investment

FinanceEntry({ required this.id, required this.type, required this.date, required this.amount, this.note, this.expenseCategory, this.savingCurrency, this.savingDelta, this.investmentType, });

Map<String, dynamic> toJson() => { 'id': id, 'type': type.name, 'date': date.toIso8601String(), 'amount': amount, 'note': note, 'expenseCategory': expenseCategory, 'savingCurrency': savingCurrency?.name, 'savingDelta': savingDelta, 'investmentType': investmentType?.name, };

factory FinanceEntry.fromJson(Map<String, dynamic> j) => FinanceEntry( id: j['id'], type: EntryType.values.firstWhere((e) => e.name == j['type']), date: DateTime.parse(j['date']), amount: (j['amount'] as num).toDouble(), note: j['note'], expenseCategory: j['expenseCategory'], savingCurrency: j['savingCurrency'] == null ? null : SavingCurrency.values .firstWhere((e) => e.name == j['savingCurrency']), savingDelta: j['savingDelta'] == null ? null : (j['savingDelta'] as num).toDouble(), investmentType: j['investmentType'] == null ? null : InvestmentType.values .firstWhere((e) => e.name == j['investmentType']), ); }

/// ===== Persistence ===== class Store { static const _k = 'finance_entries';

static Future<List<FinanceEntry>> load() async { final sp = await SharedPreferences.getInstance(); final raw = sp.getString(_k); if (raw == null) return []; final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); return list.map(FinanceEntry.fromJson).toList() ..sort((a, b) => b.date.compareTo(a.date)); }

static Future<void> save(List<FinanceEntry> entries) async { final sp = await SharedPreferences.getInstance(); final raw = jsonEncode(entries.map((e) => e.toJson()).toList()); await sp.setString(_k, raw); } }

/// ===== Root (Bottom Nav) ===== class RootPage extends StatefulWidget { const RootPage({super.key}); @override State<RootPage> createState() => _RootPageState(); }

class _RootPageState extends State<RootPage> { int _idx = 0; List<FinanceEntry> _entries = [];

@override void initState() { super.initState(); _refresh(); }

Future<void> _refresh() async { final data = await Store.load(); setState(() => _entries = data); }

void _addEntry(FinanceEntry e) async { final list = [..._entries, e]..sort((a, b) => b.date.compareTo(a.date)); await Store.save(list); setState(() => _entries = list); }

void _deleteEntry(String id) async { final list = _entries.where((e) => e.id != id).toList(); await Store.save(list); setState(() => _entries = list); }

void _updateEntry(FinanceEntry u) async { final list = _entries.map((e) => e.id == u.id ? u : e).toList() ..sort((a, b) => b.date.compareTo(a.date)); await Store.save(list); setState(() => _entries = list); }

@override Widget build(BuildContext context) { final pages = [ DashboardPage(entries: _entries, onRefresh: _refresh), AddEntryPage(onAdd: _addEntry), IncomesPage(entries: _entries, onDelete: _deleteEntry), ExpensesPage(entries: _entries, onDelete: _deleteEntry), SavingsPage(entries: _entries), InvestmentsPage(entries: _entries, onDelete: _deleteEntry, onEdit: _updateEntry), const GoalsPage(), SettingsPage(onClear: () async { await Store.save([]); setState(() => _entries = []); }), ];

return Scaffold(
  body: SafeArea(child: pages[_idx]),
  bottomNavigationBar: NavigationBar(
    selectedIndex: _idx,
    onDestinationSelected: (i) => setState(() => _idx = i),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'داشبورد'),
      NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'افزودن'),
      NavigationDestination(icon: Icon(Icons.call_received_outlined), label: 'درآمدها'),
      NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'هزینه‌ها'),
      NavigationDestination(icon: Icon(Icons.savings_outlined), label: 'پس‌انداز'),
      NavigationDestination(icon: Icon(Icons.trending_up_outlined), label: 'سرمایه‌گذاری'),
      NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'اهداف'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
    ],
  ),
);

} }

/// ===== Dashboard ===== class DashboardPage extends StatelessWidget { final List<FinanceEntry> entries; final Future<void> Function() onRefresh; const DashboardPage({super.key, required this.entries, required this.onRefresh});

double get income => entries .where((e) => e.type == EntryType.income) .fold(0.0, (p, e) => p + e.amount);

double get expenses => entries .where((e) => e.type == EntryType.expense) .fold(0.0, (p, e) => p + e.amount);

double get savingIrr => entries .where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr) .fold(0.0, (p, e) => p + (e.savingDelta ?? 0));

double get savingUsd => entries .where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd) .fold(0.0, (p, e) => p + (e.savingDelta ?? 0));

double get investedTotal => entries .where((e) => e.type == EntryType.investment) .fold(0.0, (p, e) => p + e.amount);

@override Widget build(BuildContext context) { final balance = income - expenses;

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
      const Text('آخرین تراکنش‌ها',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...entries.take(10).map((e) => _EntryTile(e)).toList(),
    ],
  ),
);

} }

class _StatCard extends StatelessWidget { final String title; final double value; const _StatCard({required this.title, required this.value}); @override Widget build(BuildContext context) { return Card( elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding( padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)), const SizedBox(height: 6), Text(fmt(value), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), ]), ), ); } }

class _MiniStat { final String title; final double value; const _MiniStat({required this.title, required this.value}); }

class _StatRow extends StatelessWidget { final List<_MiniStat> items; const _StatRow({required this.items}); @override Widget build(BuildContext context) { return Row( children: items .map((i) => Expanded( child: Card( elevation: 0, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(16)), child: Padding( padding: const EdgeInsets.all(12), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(i.title, style: const TextStyle( fontSize: 12, color: Colors.black54)), const SizedBox(height: 4), Text(fmt(i.value), style: const TextStyle( fontSize: 18, fontWeight: FontWeight.bold)), ], ), ), ), )) .toList(), ); } }

class _EntryTile extends StatelessWidget { final FinanceEntry e; const _EntryTile(this.e); @override Widget build(BuildContext context) { final icon = switch (e.type) { EntryType.income => Icons.north_east, EntryType.expense => Icons.south_west, EntryType.saving => Icons.savings, EntryType.investment => Icons.trending_up, }; final subtitle = [ if (e.expenseCategory != null) e.expenseCategory!, if (e.savingCurrency != null) (e.savingCurrency == SavingCurrency.irr ? 'تومان' : 'دلار'), if (e.investmentType != null) { InvestmentType.gold: 'طلا', InvestmentType.stocks: 'بورس/صندوق', InvestmentType.crypto: 'کریپتو', InvestmentType.other: 'متفرقه', }[e.investmentType]!, if (e.type == EntryType.income && (e.note != null && e.note!.isNotEmpty)) 'منبع: ${e.note!}', ].join(' · ');

return ListTile(
  leading: CircleAvatar(child: Icon(icon)),
  title: Text(fmt(e.amount)),
  subtitle: Text(subtitle.isEmpty ? (e.note ?? '') : subtitle),
  trailing: Text('${e.date.year}/${e.date.month}/${e.date.day}'),
);

} }

/// ===== Add Entry Page ===== class AddEntryPage extends StatefulWidget { final void Function(FinanceEntry) onAdd; const AddEntryPage({super.key, required this.onAdd}); @override State<AddEntryPage> createState() => _AddEntryPageState(); }

class _AddEntryPageState extends State<AddEntryPage> { EntryType _type = EntryType.expense; final _amountCtrl = TextEditingController(); final _noteCtrl = TextEditingController(); String? _expenseCategory; SavingCurrency _savingCurrency = SavingCurrency.irr; InvestmentType _investmentType = InvestmentType.gold; DateTime _date = DateTime.now();

final expenseCategories = const [ 'قبوض (آب/برق/گاز/اینترنت/موبایل)', 'باشگاه - شهریه', 'باشگاه - تغذیه/مکمل', 'باشگاه - تجهیزات', 'بیرون رفتن', 'وسایل خانه', 'کمپ و تجهیزات', 'هزینه ماشین', 'مصرفی خانه', 'نظافت/بهداشت', 'تعمیرات', 'متفرقه', ];

void _submit() { final amount = double.tryParse(_amountCtrl.text.trim()); if (amount == null || amount <= 0) { ScaffoldMessenger.of(context) .showSnackBar(const SnackBar(content: Text('مبلغ معتبر وارد کنید'))); return; } FinanceEntry e; switch (_type) { case EntryType.income: e = FinanceEntry( id: UniqueKey().toString(), type: EntryType.income, date: _date, amount: amount, note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(), ); break; case EntryType.expense: e = FinanceEntry( id: UniqueKey().toString(), type: EntryType.expense, date: _date, amount: amount, expenseCategory: _expenseCategory ?? 'متفرقه', note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(), ); break; case EntryType.saving: e = FinanceEntry( id: UniqueKey().toString(), type: EntryType.saving, date: _date, amount: amount, savingCurrency: _savingCurrency, savingDelta: amount, note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(), ); break; case EntryType.investment: e = FinanceEntry( id: UniqueKey().toString(), type: EntryType.investment, date: _date, amount: amount, investmentType: _investmentType, note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(), ); break; } widget.onAdd(e); _amountCtrl.clear(); _noteCtrl.clear(); ScaffoldMessenger.of(context) .showSnackBar(const SnackBar(content: Text('ذخیره شد'))); }

@override Widget build(BuildContext context) { return Scaffold( appBar: AppBar(title: const Text('افزودن تراکنش')), body: ListView( padding: const EdgeInsets.all(16), children: [ SegmentedButton<EntryType>( segments: const [ ButtonSegment(value: EntryType.expense, label: Text('هزینه')), ButtonSegment(value: EntryType.income, label: Text('درآمد')), ButtonSegment(value: EntryType.saving, label: Text('پس‌انداز')), ButtonSegment(value: EntryType.investment, label: Text('سرمایه‌گذاری')), ], selected: {_type}, onSelectionChanged: (s) => setState(() => _type = s.first), ), const SizedBox(height: 12), TextField( controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration( labelText: 'مبلغ', border: OutlineInputBorder(), ), ), const SizedBox(height: 12), if (_type == EntryType.expense) DropdownButtonFormField<String>( value: _expenseCategory, items: expenseCategories .map((c) => DropdownMenuItem(value: c, child: Text(c))) .toList(), onChanged: (v) => setState(() => _expenseCategory = v), decoration: const InputDecoration( labelText: 'دسته هزینه', border: OutlineInputBorder(), ), ), if (_type == EntryType.saving) ...[ const SizedBox(height: 12), DropdownButtonFormField<SavingCurrency>( value: _savingCurrency, items: const [ DropdownMenuItem(value: SavingCurrency.irr, child: Text('تومان')), DropdownMenuItem(value: SavingCurrency.usd, child: Text('دلار')), ], onChanged: (v) => setState(() => _savingCurrency = v!), decoration: const InputDecoration( labelText: 'واحد پس‌انداز', border: OutlineInputBorder(), ), ), const SizedBox(height: 8), const Text('نکته: برای برداشت از پس‌انداز می‌توانید مبلغ منفی وارد کنید.'), ], if (_type == EntryType.investment) ...[ const SizedBox(height: 12), DropdownButtonFormField<InvestmentType>( value: _investmentType, items: const [ DropdownMenuItem(value: InvestmentType.gold, child: Text('طلا')), DropdownMenuItem(value: InvestmentType.stocks, child: Text('بورس/صندوق')), DropdownMenuItem(value: InvestmentType.crypto, child: Text('کریپتو')), DropdownMenuItem(value: InvestmentType.other, child: Text('متفرقه')), ], onChanged: (v) => setState(() => _investmentType = v!), decoration: const InputDecoration( labelText: 'نوع سرمایه‌گذاری', border: OutlineInputBorder(), ), ), ], const SizedBox(height: 12), TextField( controller: _noteCtrl, decoration: const InputDecoration( labelText: 'توضیحات / منبع درآمد (اختیاری)', border: OutlineInputBorder(), ), ), const SizedBox(height: 12), Row( children: [ Expanded( child: OutlinedButton.icon( icon: const Icon(Icons.calendar_today_outlined), label: Text('${_date.year}/${_date.month}/${_date.day}'), onPressed: () async { final d = await showDatePicker( context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date, ); if (d != null) setState(() => _date = d); }, ), ), const SizedBox(width: 8), Expanded( child: FilledButton.icon( icon: const Icon(Icons.save_outlined), label: const Text('ذخیره'), onPressed: _submit, ), ), ], ), const SizedBox(height: 72), ], ), floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, floatingActionButton: const SizedBox.shrink(), ); } }

/// ===== Incomes Page ===== class IncomesPage extends StatelessWidget { final List<FinanceEntry> entries; final void Function(String id)? onDelete; const IncomesPage({super.key, required this.entries, this.onDelete});

@override Widget build(BuildContext context) { final incomes = entries.where((e) => e.type == EntryType.income).toList(); final byNote = <String, double>{}; for (final e in incomes) { final k = (e.note == null || e.note!.trim().isEmpty) ? 'متفرقه' : e.note!.trim(); byNote[k] = (byNote[k] ?? 0) + e.amount; }

return Scaffold(
  appBar: AppBar(title: const Text('درآمدها')),
  body: ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _PieCard(title: 'سهم هر منبع درآمد', data: byNote),
      const SizedBox(height: 8),
      ...incomes.map((e) => (onDelete == null)
          ? ListTile(
              leading: const Icon(Icons.north_east),
              title: Text(fmt(e.amount)),
              subtitle: Text(e.note ?? 'متفرقه'),
              trailing:
                  Text('${e.date.year}/${e.date.month}/${e.date.day}'),
            )
          : Dismissible(
              key: ValueKey(e.id),
              background: Container(color: Colors.redAccent),
              onDismissed: (_) => onDelete!(e.id),
              child: ListTile(
                leading: const Icon(Icons.north_east),
                title: Text(fmt(e.amount)),
                subtitle: Text(e.note ?? 'متفرقه'),
                trailing: Text(
                    '${e.date.year}/${e.date.month}/${e.date.day}'),
              ),
            )),
    ],
  ),
);

} }

/// ===== Expenses Page ===== class ExpensesPage extends StatelessWidget { final List<FinanceEntry> entries; final void Function(String id) onDelete; const ExpensesPage({super.key, required this.entries, required this.onDelete});

@override Widget build(BuildContext context) { final expenses = entries.where((e) => e.type == EntryType.expense).toList(); final byCat = <String, double>{}; for (final e in expenses) { final k = e.expenseCategory ?? 'متفرقه'; byCat[k] = (byCat[k] ?? 0) + e.amount; }

return Scaffold(
  appBar: AppBar(title: const Text('هزینه‌ها')),
  body: ListView(
    padding: const EdgeInsets.all(12),
    children: [
      _PieCard(title: 'سهم هر دسته از هزینه‌ها', data: byCat),
      const SizedBox(height: 8),
      ...expenses.map((e) => Dismissible(
            key: ValueKey(e.id),
            background: Container(color: Colors.redAccent),
            onDismissed: (_) => onDelete(e.id),
            child: ListTile(
              leading: const Icon(Icons.south_west),
              title: Text(fmt(e.amount)),
              subtitle: Text(e.expenseCategory ?? 'متفرقه'),
              trailing:
                  Text('${e.date.year}/${e.date.month}/${e.date.day}'),
            ),
          )),
      const SizedBox(height: 72),
    ],
  ),
);

} }

/// ===== Savings Page ===== class SavingsPage extends StatelessWidget { final List<FinanceEntry> entries; const SavingsPage({super.key, required this.entries});

@override Widget build(BuildContext context) { final irr = entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr); final usd = entries.where((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd); final irrSum = irr.fold(0.0, (p, e) => p + (e.savingDelta ?? 0)); final usdSum = usd.fold(0.0, (p, e) => p + (e.savingDelta ?? 0));

final data = {'تومان': irrSum, 'دلار': usdSum};

return Scaffold(
  appBar: AppBar(title: const Text('پس‌انداز')),
  body: ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _PieCard(title: 'سهم هر واحد از پس‌انداز', data: data),
      const SizedBox(height: 8),
      _StatCard(title: 'پس‌انداز تومان', value: irrSum),
      const SizedBox(height: 8),
      _StatCard(title: 'پس‌انداز دلار', value: usdSum),
      const SizedBox(height: 72),
    ],
  ),
);

} }

/// ===== Investments Page (delete + edit) ===== class InvestmentsPage extends StatelessWidget { final List<FinanceEntry> entries; final void Function(String id)? onDelete; final void Function(FinanceEntry updated)? onEdit;

const InvestmentsPage({ super.key, required this.entries, this.onDelete, this.onEdit, });

String vt(InvestmentType t) => { InvestmentType.gold: 'طلا', InvestmentType.stocks: 'بورس/صندوق', InvestmentType.crypto: 'کریپتو', InvestmentType.other: 'متفرقه', }[t]!;

@override Widget build(BuildContext context) { final inv = entries.where((e) => e.type == EntryType.investment).toList(); final byType = <InvestmentType, double>{}; for (final e in inv) { final k = e.investmentType ?? InvestmentType.other; byType[k] = (byType[k] ?? 0) + e.amount; } final data = byType.map((k, v) => MapEntry(vt(k), v));

return Scaffold(
  appBar: AppBar(title: const Text('سرمایه‌گذاری')),
  body: ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _PieCard(title: 'سهم هر نوع از سرمایه‌گذاری', data: data),
      const SizedBox(height: 8),
      ...inv.map((e) {
        final tile = ListTile(
          leading: const Icon(Icons.trending_up),
          title: Text(fmt(e.amount)),
          subtitle: Text(vt(e.investmentType ?? InvestmentType.other)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'ویرایش',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit == null ? null : () => _openEditDialog(context, e),
              ),
              const SizedBox(width: 4),
              Text('${e.date.year}/${e.date.month}/${e.date.day}'),
            ],
          ),
          onTap: onEdit == null ? null : () => _openEditDialog(context, e),
        );

        if (onDelete == null) return tile;
        return Dismissible(
          key: ValueKey(e.id),
          background: Container(color: Colors.redAccent),
          onDismissed: (_) => onDelete!(e.id),
          child: tile,
        );
      }),
      const SizedBox(height: 72),
    ],
  ),
);

}

Future<void> _openEditDialog(BuildContext context, FinanceEntry e) async { if (onEdit == null) return; final amountCtrl = TextEditingController(text: e.amount.toStringAsFixed(0)); final noteCtrl   = TextEditingController(text: e.note ?? ''); InvestmentType type = e.investmentType ?? InvestmentType.other; DateTime date = e.date;

final ok = await showDialog<bool>(
  context: context,
  builder: (_) => StatefulBuilder(
    builder: (ctx, setState) => AlertDialog(
      title: const Text('ویرایش سرمایه‌گذاری'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              value: type,
              items: const [
                DropdownMenuItem(value: InvestmentType.gold, child: Text('طلا')),
                DropdownMenuItem(value: InvestmentType.stocks, child: Text('بورس/صندوق')),
                DropdownMenuItem(value: InvestmentType.crypto, child: Text('کریپتو')),
                DropdownMenuItem(value: InvestmentType.other, child: Text('متفرقه')),
              ],
              onChanged: (v) => setState(() => type = v ?? type),
              decoration: const InputDecoration(
                labelText: 'نوع',
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
                  context: ctx,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: date,
                );
                if (d != null) setState(() => date = d);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ذخیره')),
      ],
    ),
  ),
);

if (ok == true) {
  final a = double.tryParse(amountCtrl.text.trim());
  if (a != null && a > 0) {
    final updated = FinanceEntry(
      id: e.id,
      type: EntryType.investment,
      date: date,
      amount: a,
      investmentType: type,
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );
    onEdit!(updated);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('مبلغ معتبر وارد کنید')),
    );
  }
}

} }

/// ===== Goals (Checklist) ===== class Goal { final String id; final String title; final bool done; Goal({required this.id, required this.title, required this.done}); Goal copyWith({String? title, bool? done}) => Goal(id: id, title: title ?? this.title, done: done ?? this.done); Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done}; factory Goal.fromJson(Map<String, dynamic> j) => Goal(id: j['id'], title: j['title'], done: j['done'] ?? false); }

class GoalsStore { static const _k = 'finance_goals'; static Future<List<Goal>> load() async { final sp = await SharedPreferences.getInstance(); final raw = sp.getString(_k); if (raw == null) return []; final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); return list.map(Goal.fromJson).toList(); } static Future<void> save(List<Goal> goals) async { final sp = await SharedPreferences.getInstance(); await sp.setString(_k, jsonEncode(goals.map((g) => g.toJson()).toList())); } }

class GoalsPage extends StatefulWidget { const GoalsPage({super.key}); @override State<GoalsPage> createState() => _GoalsPageState(); }

class _GoalsPageState extends State<GoalsPage> { List<Goal> _goals = []; final TextEditingController _ctrl = TextEditingController();

@override void initState() { super.initState(); _load(); } Future<void> _load() async { _goals = await GoalsStore.load(); if (mounted) setState(() {}); } Future<void> _addGoal(String title) async { final g = Goal(id: UniqueKey().toString(), title: title, done: false); _goals = [..._goals, g]; await GoalsStore.save(_goals); if (mounted) setState(() {}); } Future<void> _toggle(String id, bool? v) async { _goals = _goals.map((g) => g.id == id ? g.copyWith(done: v ?? false) : g).toList(); await GoalsStore.save(_goals); if (mounted) setState(() {}); } Future<void> _delete(String id) async { _goals = _goals.where((g) => g.id != id).toList(); await GoalsStore.save(_goals); if (mounted) setState(() {}); } Future<void> _openAddDialog() async { ctrl.clear(); final ok = await showDialog<bool>( context: context, builder: () => AlertDialog( title: const Text('افزودن هدف'), content: TextField( controller: _ctrl, decoration: const InputDecoration(hintText: 'مثلاً: تلویزیون 55 اینچ'), autofocus: true, ), actions: [ TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('افزودن')), ], ), ); if (ok == true && _ctrl.text.trim().isNotEmpty) { await _addGoal(_ctrl.text.trim()); } }

@override Widget build(BuildContext context) { return Scaffold( appBar: AppBar(title: const Text('اهداف خرید')), body: ListView( padding: const EdgeInsets.fromLTRB(16, 16, 16, 88), children: [ if (goals.isEmpty) const Padding( padding: EdgeInsets.all(24), child: Center(child: Text('هنوز هدفی ثبت نشده. دکمه + پایین را بزنید')), ), ...goals.map((g) => Dismissible( key: ValueKey('goal${g.id}'), background: Container(color: Colors.redAccent), onDismissed: () => delete(g.id), child: CheckboxListTile( key: ValueKey('checkbox${g.id}'), value: g.done, onChanged: (v) => _toggle(g.id, v), title: Text( g.title, style: TextStyle( decoration: g.done ? TextDecoration.lineThrough : null, ), ), controlAffinity: ListTileControlAffinity.leading, ), )), ], ), floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, floatingActionButton: Padding( padding: const EdgeInsets.only(bottom: 72), child: FloatingActionButton.large( onPressed: _openAddDialog, child: const Icon(Icons.add), ), ), ); } }

/// ===== Settings ===== class SettingsPage extends StatelessWidget { final Future<void> Function()? onClear; const SettingsPage({super.key, this.onClear});

@override Widget build(BuildContext context) { return Scaffold( appBar: AppBar(title: const Text('تنظیمات')), body: ListView( padding: const EdgeInsets.all(16), children: [ const ListTile( leading: Icon(Icons.info_outline), title: Text('دسته‌بندی‌ها ثابت هستند (فعلاً)'), subtitle: Text('در نسخه بعدی می‌توانید دسته جدید اضافه کنید.'), ), const SizedBox(height: 12), FilledButton.tonalIcon( onPressed: onClear, icon: const Icon(Icons.delete_forever), label: const Text('حذف همه داده‌ها'), ), ], ), ); } }

/// ===== Pie Card Widget ===== class _PieCard extends StatelessWidget { final String title; final Map<String, double> data; // label -> value const _PieCard({required this.title, required this.data});

@override Widget build(BuildContext context) { final total = data.values.fold<double>(0, (p, v) => p + v); return Card( elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding( padding: const EdgeInsets.all(16), child: total <= 0 ? const Text('داده‌ای برای نمایش نیست') : Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(title, style: const TextStyle( fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(height: 12), SizedBox( height: 180, child: PieChart( PieChartData( sectionsSpace: 2, centerSpaceRadius: 32, sections: _buildSections(), ), ), ), const SizedBox(height: 8), Wrap( spacing: 8, runSpacing: 4, children: data.entries.map((e) { final i = data.keys.toList().indexOf(e.key); return Row( mainAxisSize: MainAxisSize.min, children: [ Container( width: 10, height: 10, decoration: BoxDecoration( color: _colorFor(i), shape: BoxShape.circle, ), ), const SizedBox(width: 6), Text('${e.key}: ${fmt(e.value)}'), ], ); }).toList(), ), ], ), ), ); }

List<PieChartSectionData> _buildSections() { final entries = data.entries.toList(); final total = data.values.fold<double>(0, (p, v) => p + v); return List.generate(entries.length, (i) { final v = entries[i].value; return PieChartSectionData( value: v, title: total == 0 ? '' : '${(v / total * 100).toStringAsFixed(0)}%', radius: 60, titleStyle: const TextStyle( fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, ), color: _colorFor(i), ); }); }

Color _colorFor(int i) { const palette = [ Colors.teal, Colors.blue, Colors.orange, Colors.pink, Colors.indigo, Colors.green, Colors.cyan, Colors.amber, Colors.purple, Colors.brown, ]; return palette[i % palette.length]; } }

