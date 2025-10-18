// Flutter minimal personal finance app (Android-only MVP)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinanceApp());
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

  // expense
  final String? expenseCategory;

  // saving
  final SavingCurrency? savingCurrency; // irr/usd
  final double? savingDelta; // +increase, -withdraw

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
        id: j['id'] as String,
        type: EntryType.values.firstWhere((e) => e.name == j['type']),
        date: DateTime.parse(j['date']),
        amount: (j['amount'] as num).toDouble(),
        note: j['note'],
        expenseCategory: j['expenseCategory'],
        savingCurrency: (j['savingCurrency'] == null)
            ? null
            : SavingCurrency.values
                .firstWhere((e) => e.name == j['savingCurrency']),
        savingDelta: (j['savingDelta'] == null)
            ? null
            : (j['savingDelta'] as num).toDouble(),
        investmentType: (j['investmentType'] == null)
            ? null
            : InvestmentType.values
                .firstWhere((e) => e.name == j['investmentType']),
      );
}

// ===== Simple local storage =====
class Store {
  static Future<void> save(List<FinanceEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final list = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('entries', list);
  }

  static Future<List<FinanceEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('entries') ?? [];
    return list.map((s) => FinanceEntry.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('entries');
  }
}

// ===== App & Root =====
class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with TickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  List<FinanceEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // ----- helpers inside state -----
  Future<void> _refresh() async {
    _entries = await Store.load();
    setState(() {});
  }

  Future<void> _addEntry(FinanceEntry e) async {
    _entries.add(e);
    await Store.save(_entries);
    setState(() {});
  }

  Future<void> _delete(FinanceEntry e) async {
    _entries.remove(e);
    await Store.save(_entries);
    setState(() {});
  }

  double _sum(Iterable<FinanceEntry> xs) =>
      xs.fold(0.0, (p, e) => p + e.amount);

  double get income =>
      _sum(_entries.where((e) => e.type == EntryType.income));
  double get expenses =>
      _sum(_entries.where((e) => e.type == EntryType.expense));
  double get savingIrr => _entries
      .where((e) =>
          e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr)
      .fold(0.0, (p, e) => p + (e.savingDelta ?? e.amount));
  double get savingUsd => _entries
      .where((e) =>
          e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd)
      .fold(0.0, (p, e) => p + (e.savingDelta ?? e.amount));
  double get investedTotal =>
      _sum(_entries.where((e) => e.type == EntryType.investment));

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        income: income,
        expenses: expenses,
        savingIrr: savingIrr,
        savingUsd: savingUsd,
        investedTotal: investedTotal,
        onRefresh: _refresh,
      ),
      ExpensesPage(entries: _entries, onDelete: _delete),
      SavingsPage(entries: _entries),
      InvestmentsPage(entries: _entries),
      SettingsPage(
        onClear: () async {
          await Store.clear();
          setState(() => _entries = []);
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Finance'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'داشبورد', icon: Icon(Icons.space_dashboard_outlined)),
            Tab(text: 'هزینه‌ها', icon: Icon(Icons.receipt_long)),
            Tab(text: 'پس‌انداز', icon: Icon(Icons.savings_outlined)),
            Tab(text: 'سرمایه‌گذاری', icon: Icon(Icons.trending_up)),
            Tab(text: 'تنظیمات', icon: Icon(Icons.settings)),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final e = await Navigator.push<FinanceEntry>(
            context,
            MaterialPageRoute(builder: (_) => AddEntryPage()),
          );
          if (e != null) _addEntry(e);
        },
        icon: const Icon(Icons.add),
        label: const Text('افزودن'),
      ),
    );
  }
}

// ===== Pages =====

class DashboardPage extends StatelessWidget {
  final double income, expenses, savingIrr, savingUsd, investedTotal;
  final Future<void> Function() onRefresh;
  const DashboardPage({
    super.key,
    required this.income,
    required this.expenses,
    required this.savingIrr,
    required this.savingUsd,
    required this.investedTotal,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final net = income - expenses;
    card(String t, String v, IconData i) => Card(
          child: ListTile(leading: Icon(i), title: Text(t), trailing: Text(v)),
        );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          card('درآمد', income.toStringAsFixed(0), Icons.attach_money),
          card('هزینه‌ها', expenses.toStringAsFixed(0), Icons.money_off),
          card('پس‌انداز (تومان)', savingIrr.toStringAsFixed(0), Icons.savings),
          card('پس‌انداز (دلار)', savingUsd.toStringAsFixed(2), Icons.savings),
          card('کل سرمایه‌گذاری', investedTotal.toStringAsFixed(0),
              Icons.trending_up),
          const SizedBox(height: 8),
          Card(
            color: net >= 0 ? Colors.green.withOpacity(.15) : Colors.red.withOpacity(.15),
            child: ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('تراز ماه'),
              trailing: Text(net.toStringAsFixed(0)),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpensesPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  final Future<void> Function(FinanceEntry) onDelete;
  const ExpensesPage({super.key, required this.entries, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final items =
        entries.where((e) => e.type == EntryType.expense).toList().reversed;
    return ListView(
      children: [
        for (final e in items)
          Dismissible(
            key: ValueKey(e.id),
            background: Container(color: Colors.red),
            onDismissed: (_) => onDelete(e),
            child: ListTile(
              title: Text(e.expenseCategory ?? 'هزینه'),
              subtitle: Text(e.note ?? ''),
              trailing: Text(e.amount.toStringAsFixed(0)),
            ),
          )
      ],
    );
  }
}

class SavingsPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  const SavingsPage({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final irr = entries.where((e) =>
        e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr);
    final usd = entries.where((e) =>
        e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd);
    tile(String t, Iterable<FinanceEntry> xs) => Card(
          child: ListTile(
            title: Text(t),
            trailing: Text(xs.fold<double>(
                    0, (p, e) => p + (e.savingDelta ?? e.amount))
                .toStringAsFixed(t.contains('USD') ? 2 : 0)),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        tile('پس‌انداز IRR', irr),
        tile('پس‌انداز USD', usd),
      ],
    );
  }
}

class InvestmentsPage extends StatelessWidget {
  final List<FinanceEntry> entries;
  const InvestmentsPage({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final inv = entries.where((e) => e.type == EntryType.investment);
    final byType = <InvestmentType, double>{};
    for (final e in inv) {
      final k = e.investmentType ?? InvestmentType.other;
      byType[k] = (byType[k] ?? 0) + e.amount;
    }
    card(String t, double v) => Card(
          child: ListTile(title: Text(t), trailing: Text(v.toStringAsFixed(0))),
        );
    String name(InvestmentType t) {
      switch (t) {
        case InvestmentType.gold:
          return 'طلا';
        case InvestmentType.stocks:
          return 'بورس/صندوق';
        case InvestmentType.crypto:
          return 'کریپتو';
        case InvestmentType.other:
          return 'متفرقه';
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final e in byType.entries) card(name(e.key), e.value),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  final Future<void> Function()? onClear;
  SettingsPage({super.key, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('دسته‌بندی‌ها ثابت هستند (نسخه MVP)'),
            subtitle: Text('در نسخه‌های بعد قابل افزودن هستند.'),
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

// ===== Add Entry (very simple form) =====
class AddEntryPage extends StatefulWidget {
  AddEntryPage({super.key});
  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  EntryType type = EntryType.expense;
  SavingCurrency savingCurrency = SavingCurrency.irr;
  InvestmentType investmentType = InvestmentType.other;

  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final expenseCatCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    Widget typeSpecific() {
      switch (type) {
        case EntryType.expense:
          return TextField(
            controller: expenseCatCtrl,
            decoration: const InputDecoration(
              labelText: 'دسته هزینه (مثلاً قبض/باشگاه/بیرون)',
            ),
          );
        case EntryType.saving:
          return Column(children: [
            const SizedBox(height: 8),
            DropdownButtonFormField<SavingCurrency>(
              value: savingCurrency,
              items: const [
                DropdownMenuItem(
                    value: SavingCurrency.irr, child: Text('تومان')),
                DropdownMenuItem(
                    value: SavingCurrency.usd, child: Text('دلار')),
              ],
              onChanged: (v) => setState(() => savingCurrency = v!),
              decoration: const InputDecoration(labelText: 'ارز پس‌انداز'),
            ),
            const SizedBox(height: 6),
            const Text('عدد مثبت = افزایش، منفی = برداشت'),
          ]);
        case EntryType.investment:
          return DropdownButtonFormField<InvestmentType>(
            value: investmentType,
            items: const [
              DropdownMenuItem(
                  value: InvestmentType.gold, child: Text('طلا')),
              DropdownMenuItem(
                  value: InvestmentType.stocks, child: Text('بورس/صندوق')),
              DropdownMenuItem(
                  value: InvestmentType.crypto, child: Text('کریپتو')),
              DropdownMenuItem(
                  value: InvestmentType.other, child: Text('متفرقه')),
            ],
            onChanged: (v) => setState(() => investmentType = v!),
            decoration: const InputDecoration(labelText: 'نوع سرمایه‌گذاری'),
          );
        case EntryType.income:
          return const SizedBox.shrink();
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('افزودن تراکنش')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<EntryType>(
            value: type,
            items: const [
              DropdownMenuItem(value: EntryType.income, child: Text('درآمد')),
              DropdownMenuItem(value: EntryType.expense, child: Text('هزینه')),
              DropdownMenuItem(value: EntryType.saving, child: Text('پس‌انداز')),
              DropdownMenuItem(
                  value: EntryType.investment, child: Text('سرمایه‌گذاری')),
            ],
            onChanged: (v) => setState(() => type = v!),
            decoration: const InputDecoration(labelText: 'نوع'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'مبلغ', hintText: 'مثلاً 250000'),
          ),
          const SizedBox(height: 8),
          typeSpecific(),
          const SizedBox(height: 8),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('مبلغ نامعتبر')));
                return;
              }
              final e = FinanceEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: type,
                date: DateTime.now(),
                amount: amount,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                expenseCategory: type == EntryType.expense
                    ? (expenseCatCtrl.text.trim().isEmpty
                        ? 'هزینه'
                        : expenseCatCtrl.text.trim())
                    : null,
                savingCurrency:
                    type == EntryType.saving ? savingCurrency : null,
                savingDelta:
                    type == EntryType.saving ? amount : null,
                investmentType:
                    type == EntryType.investment ? investmentType : null,
              );
              Navigator.pop(context, e);
            },
            icon: const Icon(Icons.check),
            label: const Text('ثبت'),
          ),
        ],
      ),
    );
  }
}
