// Flutter Personal Finance App (Android MVP) — v2
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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

  // expense (two-level)
  final String? expenseGroup; // e.g., Grocery, Cleaning, Utilities, Clothing
  final String? expenseSub;   // e.g., Dairy/شیر, Meat/مرغ, Internet, ...

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
    this.expenseGroup,
    this.expenseSub,
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
        'expenseGroup': expenseGroup,
        'expenseSub': expenseSub,
        'savingCurrency': savingCurrency?.name,
        'savingDelta': savingDelta,
        'investmentType': investmentType?.name,
      };

  factory FinanceEntry.fromJson(Map<String, dynamic> j) => FinanceEntry(
        id: j['id'] as String,
        type: EntryType.values.firstWhere((e) => e.name == j['type']),
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toDouble(),
        note: j['note'] as String?,
        expenseGroup: j['expenseGroup'] as String?,
        expenseSub: j['expenseSub'] as String?,
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

// ===== Local storage =====
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

// ===== Formatting helpers =====
final _fmtFa = NumberFormat.decimalPattern('fa_IR');
String fmtNum(num n) => _fmtFa.format(n);

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(',', '').replaceAll('٬', '');
    if (text.isEmpty) return const TextEditingValue(text: '');
    final isNeg = text.startsWith('-');
    if (isNeg) text = text.substring(1);
    final parts = text.split('.');
    String intPart = parts[0].replaceAll(RegExp(r'\D'), '');
    String decPart = parts.length > 1 ? parts[1] : '';
    // add commas
    final chars = intPart.split('');
    final buf = StringBuffer();
    for (int i = 0; i < chars.length; i++) {
      final idx = chars.length - i;
      buf.write(chars[i]);
      if (idx > 1 && (idx - 1) % 3 == 0) buf.write(',');
    }
    final out = (isNeg ? '-' : '') + buf.toString() + (decPart.isNotEmpty ? '.$decPart' : '');
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
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
  late final TabController _tabs = TabController(length: 6, vsync: this);
  List<FinanceEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    _entries = await Store.load();
    setState(() {});
  }

  Future<void> _add(FinanceEntry e) async {
    _entries.add(e);
    await Store.save(_entries);
    setState(() {});
  }

  Future<void> _remove(FinanceEntry e) async {
    _entries.remove(e);
    await Store.save(_entries);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(entries: _entries, onRefresh: _refresh),
      IncomePage(entries: _entries, onDelete: _confirmDelete),
      ExpensesPage(entries: _entries, onDelete: _confirmDelete),
      SavingsPage(entries: _entries, onDelete: _confirmDelete),
      InvestmentsPage(entries: _entries, onDelete: _confirmDelete),
      SettingsPage(onClear: () async {
        await Store.clear();
        setState(() => _entries = []);
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Finance'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'داشبورد', icon: Icon(Icons.space_dashboard_outlined)),
            Tab(text: 'درآمد', icon: Icon(Icons.north_east)),
            Tab(text: 'هزینه‌ها', icon: Icon(Icons.south_west)),
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
          if (e != null) _add(e);
        },
        icon: const Icon(Icons.add),
        label: const Text('افزودن'),
      ),
    );
  }

  Future<void> _confirmDelete(FinanceEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف تراکنش؟'),
        content: const Text('آیا مطمئنی؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      final idx = _entries.indexOf(e);
      await _remove(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('حذف شد'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              _entries.insert(idx, e);
              await Store.save(_entries);
              setState(() {});
            },
          ),
        ),
      );
    }
  }
}

// ===== Reusable UI =====
class StatCard extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color? color;
  const StatCard({super.key, required this.title, required this.value, required this.icon, this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ===== Dashboard with donut =====
class DashboardPage extends StatelessWidget {
  final List<FinanceEntry> entries; final Future<void> Function() onRefresh;
  const DashboardPage({super.key, required this.entries, required this.onRefresh});

  Map<String, double> _expenseByGroup() {
    final m = <String, double>{};
    for (final e in entries.where((e) => e.type == EntryType.expense)) {
      final k = e.expenseGroup ?? 'متفرقه';
      m[k] = (m[k] ?? 0) + e.amount;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    double sumWhere(bool Function(FinanceEntry) test, [double Function(FinanceEntry)? pick]) =>
        entries.where(test).fold(0.0, (p, e) => p + (pick?.call(e) ?? e.amount));
    final inc = sumWhere((e) => e.type == EntryType.income);
    final exp = sumWhere((e) => e.type == EntryType.expense);
    final irr = sumWhere((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.irr,
        (e) => e.savingDelta ?? e.amount);
    final usd = sumWhere((e) => e.type == EntryType.saving && e.savingCurrency == SavingCurrency.usd,
        (e) => e.savingDelta ?? e.amount);
    final inv = sumWhere((e) => e.type == EntryType.investment);
    final net = inc - exp;

    final data = _expenseByGroup();
    final total = data.values.fold(0.0, (p, v) => p + v);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          StatCard(title: 'درآمد', value: fmtNum(inc), icon: Icons.north_east, color: Colors.green),
          StatCard(title: 'هزینه‌ها', value: fmtNum(exp), icon: Icons.south_west, color: Colors.red),
          StatCard(title: 'پس‌انداز (تومان)', value: fmtNum(irr), icon: Icons.savings),
          StatCard(title: 'پس‌انداز (دلار)', value: fmtNum(usd), icon: Icons.savings),
          StatCard(title: 'سرمایه‌گذاری', value: fmtNum(inv), icon: Icons.trending_up),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('تراز ماه'),
              trailing: Text(fmtNum(net), style: TextStyle(
                color: net>=0?Colors.green:Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          if (total > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('توزیع هزینه‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 200,
              child: CustomPaint(painter: _DonutPainter(data)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: data.entries.map((e) {
                final pct = (e.value/total*100).toStringAsFixed(1);
                return Chip(label: Text('${e.key}: $pct%'));
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String,double> data;
  _DonutPainter(this.data);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = math.min(size.width, size.height)/2 - 8;
    final total = data.values.fold(0.0, (p, v) => p + v);
    if (total == 0) return;
    double start = -math.pi/2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.butt;
    final colors = [
      Colors.teal, Colors.indigo, Colors.pink, Colors.orange, Colors.blueGrey,
      Colors.cyan, Colors.amber, Colors.deepPurple, Colors.brown, Colors.lime
    ];
    int i = 0;
    for (final v in data.values) {
      final sweep = (v/total) * 2*math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep; i++;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===== Income Page =====
class IncomePage extends StatelessWidget {
  final List<FinanceEntry> entries; final Future<void> Function(FinanceEntry) onDelete;
  const IncomePage({super.key, required this.entries, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final items = entries.where((e) => e.type == EntryType.income).toList().reversed.toList();
    return ListView(
      children: [
        for (final e in items)
          _DismissibleTile(entry: e, title: 'درآمد', subtitle: e.note ?? '', onDelete: onDelete),
      ],
    );
  }
}

// ===== Expenses Page (grouped) =====
class ExpensesPage extends StatelessWidget {
  final List<FinanceEntry> entries; final Future<void> Function(FinanceEntry) onDelete;
  const ExpensesPage({super.key, required this.entries, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final exps = entries.where((e) => e.type == EntryType.expense).toList();
    final byGroup = <String, List<FinanceEntry>>{};
    for (final e in exps) {
      final g = e.expenseGroup ?? 'متفرقه';
      byGroup.putIfAbsent(g, () => []).add(e);
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: byGroup.entries.map((grp) {
        final sum = grp.value.fold(0.0, (p, e) => p + e.amount);
        return Card(
          child: ExpansionTile(
            title: Text('${grp.key} • ${fmtNum(sum)}'),
            children: grp.value.reversed.map((e) => _DismissibleTile(
              entry: e,
              title: e.expenseSub ?? 'آیتم',
              subtitle: e.note ?? '',
              onDelete: onDelete,
            )).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ===== Savings Page =====
class SavingsPage extends StatelessWidget {
  final List<FinanceEntry> entries; final Future<void> Function(FinanceEntry) onDelete;
  const SavingsPage({super.key, required this.entries, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final sav = entries.where((e) => e.type == EntryType.saving).toList().reversed.toList();
    return ListView(
      children: [
        for (final e in sav)
          _DismissibleTile(
            entry: e,
            title: e.savingCurrency == SavingCurrency.irr ? 'پس‌انداز تومان' : 'پس‌انداز دلار',
            subtitle: e.note ?? '',
            onDelete: onDelete,
          ),
      ],
    );
  }
}

// ===== Investments Page =====
class InvestmentsPage extends StatelessWidget {
  final List<FinanceEntry> entries; final Future<void> Function(FinanceEntry) onDelete;
  const InvestmentsPage({super.key, required this.entries, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    String name(InvestmentType t) => {
      InvestmentType.gold: 'طلا',
      InvestmentType.stocks: 'بورس/صندوق',
      InvestmentType.crypto: 'کریپتو',
      InvestmentType.other: 'متفرقه',
    }[t]!;
    final inv = entries.where((e) => e.type == EntryType.investment).toList().reversed.toList();
    return ListView(
      children: [
        for (final e in inv)
          _DismissibleTile(
            entry: e,
            title: name(e.investmentType ?? InvestmentType.other),
            subtitle: e.note ?? '',
            onDelete: onDelete,
          ),
      ],
    );
  }
}

// ===== Shared dismissible tile with confirm+undo =====
class _DismissibleTile extends StatelessWidget {
  final FinanceEntry entry; final String title; final String subtitle; final Future<void> Function(FinanceEntry) onDelete;
  const _DismissibleTile({required this.entry, required this.title, required this.subtitle, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(entry.id),
      background: Container(color: Colors.redAccent),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('حذف تراکنش؟'),
            content: const Text('آیا مطمئنی؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لغو')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
            ],
          ),
        );
        if (ok == true) await onDelete(entry);
        return false; // حذف را خودمان مدیریت کردیم (برای امکان Undo)
      },
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconFor(entry))),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(fmtNum(entry.amount)),
      ),
    );
  }

  IconData _iconFor(FinanceEntry e) => switch (e.type) {
        EntryType.income => Icons.north_east,
        EntryType.expense => Icons.south_west,
        EntryType.saving => Icons.savings,
        EntryType.investment => Icons.trending_up,
      };
}

// ===== Settings =====
class SettingsPage extends StatelessWidget {
  final Future<void> Function()? onClear;
  const SettingsPage({super.key, this.onClear});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('نسخه MVP با گروه/زیرگروه و جداکننده هزارگان'),
          subtitle: Text('بعداً CSV و دسته‌های سفارشی هم اضافه می‌کنیم'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onClear,
          icon: const Icon(Icons.delete_forever),
          label: const Text('حذف همه داده‌ها'),
        ),
      ],
    );
  }
}

// ===== Add Entry (group/subgroup + thousands formatter) =====
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
  String? group; String? sub;

  final groups = <String, List<String>>{
    'خواربار': [
      'میوه', 'سبزی', 'لبنیات/شیر', 'لبنیات/پنیر', 'لبنیات/ماست', 'لبنیات/دوغ',
      'گوشت/مرغ', 'گوشت/ماهی', 'گوشت/گاو',
      'حبوبات/عدس', 'حبوبات/دال', 'حبوبات/لوبیا', 'حبوبات/نخود', 'حبوبات/ماش',
      'نان', 'برنج', 'روغن', 'تخم‌مرغ', 'ادویه', 'تنقلات'
    ],
    'خانه/نظافت': ['شامپو','مایع دستشویی','مایع ظرفشویی','وایتکس','مایع لباسشویی','صابون','اسکاچ','کیسه زباله'],
    'خدمات': ['آب','برق','گاز','اینترنت','تلفن'],
    'لباس': ['کفش','پیراهن','شلوار','گرم‌کن','جوراب','شورت'],
    'بیرون‌رفتن/رستوران': ['غذا','نوشیدنی','کافی‌شاپ'],
    'خانه/لوازم': ['وسایل خانه','تعمیرات'],
    'ماشین': ['سوخت','سرویس','بیمه','تعمیر'],
    'ورزش/باشگاه': ['شهریه','مکمل/پروتئین','مکمل/کراتین','جو دوسر','دانه چیا','کره بادام‌زمینی','سایر'],
    'کمپ/تفریح': ['جت‌فن','لامپ کمپینگ','سایر'],
    'متفرقه': ['سایر'],
  };

  @override
  Widget build(BuildContext context) {
    Widget typeSpecific() {
      switch (type) {
        case EntryType.expense:
          return Column(children: [
            DropdownButtonFormField<String>(
              value: group,
              items: groups.keys.map((k)=>DropdownMenuItem(value:k, child: Text(k))).toList(),
              onChanged: (v){ setState(()=>group=v); sub=null; },
              decoration: const InputDecoration(labelText: 'گروه هزینه'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: sub,
              items: (group==null? <String>[]: groups[group]!)
                .map((s)=>DropdownMenuItem(value:s, child: Text(s))).toList(),
              onChanged: (v)=> setState(()=>sub=v),
              decoration: const InputDecoration(labelText: 'زیرگروه'),
            ),
          ]);
        case EntryType.saving:
          return Column(children: [
            DropdownButtonFormField<SavingCurrency>(
              value: savingCurrency,
              items: const [
                DropdownMenuItem(value: SavingCurrency.irr, child: Text('تومان')),
                DropdownMenuItem(value: SavingCurrency.usd, child: Text('دلار')),
              ],
              onChanged: (v)=> setState(()=> savingCurrency = v!),
              decoration: const InputDecoration(labelText: 'واحد پس‌انداز'),
            ),
            const SizedBox(height: 6),
            const Text('عدد مثبت = افزایش، منفی = برداشت'),
          ]);
        case EntryType.investment:
          return DropdownButtonFormField<InvestmentType>(
            value: investmentType,
            items: const [
              DropdownMenuItem(value: InvestmentType.gold, child: Text('طلا')),
              DropdownMenuItem(value: InvestmentType.stocks, child: Text('بورس/صندوق')),
              DropdownMenuItem(value: InvestmentType.crypto, child: Text('کریپتو')),
              DropdownMenuItem(value: InvestmentType.other, child: Text('متفرقه')),
            ],
            onChanged: (v)=> setState(()=> investmentType = v!),
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
              DropdownMenuItem(value: EntryType.investment, child: Text('سرمایه‌گذاری')),
            ],
            onChanged: (v)=> setState(()=> type = v!),
            decoration: const InputDecoration(labelText: 'نوع'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ThousandsFormatter()],
            decoration: const InputDecoration(labelText: 'مبلغ'),
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
              final raw = amountCtrl.text.replaceAll(',', '').replaceAll('٬','');
              final amount = double.tryParse(raw) ?? 0;
              if (amount == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('مبلغ نامعتبر')),
                );
                return;
              }
              final e = FinanceEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: type,
                date: DateTime.now(),
                amount: amount,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                expenseGroup: type == EntryType.expense ? (group ?? 'متفرقه') : null,
                expenseSub: type == EntryType.expense ? (sub ?? 'سایر') : null,
                savingCurrency: type == EntryType.saving ? savingCurrency : null,
                savingDelta: type == EntryType.saving ? amount : null,
                investmentType: type == EntryType.investment ? investmentType : null,
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
