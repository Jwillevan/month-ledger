import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model.dart';

void main() => runApp(const BudgetApp());
const bridge = MethodChannel('monthledger/storage');
const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const ink = Color(0xff143f38);
String money(int n) =>
    '${n < 0 ? '-' : ''}\$${(n.abs() / 100).toStringAsFixed(2)}';

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Month Ledger',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: ink),
      scaffoldBackgroundColor: const Color(0xfff5f6f1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff5f6f1),
        foregroundColor: ink,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const LedgerHome(),
  );
}

class LedgerHome extends StatefulWidget {
  const LedgerHome({super.key});
  @override
  State<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends State<LedgerHome> {
  BudgetData data = BudgetData.empty();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int page = 0;
  bool loading = true, busy = false, loadFailed = false;
  String get key => monthKey(month);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final raw = await bridge.invokeMethod<String>('load');
      if (raw != null) data = BudgetData.decode(raw);
    } catch (_) {
      loadFailed = true;
    }
    if (mounted) setState(() => loading = false);
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> commit(BudgetData next) async {
    if (busy || loadFailed) return false;
    setState(() => busy = true);
    try {
      await bridge.invokeMethod('save', jsonEncode(next.toJson()));
      if (mounted) setState(() => data = next);
      return true;
    } catch (_) {
      message('Could not save. Your previous data is unchanged.');
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> chooseMonth() async {
    final d = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Choose a date in the month to view',
    );
    if (d != null) setState(() => month = DateTime(d.year, d.month));
  }

  Widget monthPicker() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: month.year == 2000 && month.month == 1
              ? null
              : () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: chooseMonth,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(
              '${months[month.month - 1]} ${month.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: month.year == 2100 && month.month == 12
              ? null
              : () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
  Widget summary(String label, int amount, {bool dark = false}) => Container(
    key: ValueKey('$page-$label'),
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dark ? ink : Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: dark ? Colors.white70 : Colors.black54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            money(amount),
            style: TextStyle(
              color: dark ? Colors.white : ink,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
  Widget totals({bool annual = false}) {
    int net(bool actual) => annual
        ? List.generate(
            12,
            (i) => data.net(DateTime(month.year, i + 1), actual),
          ).fold(0, (a, b) => a + b)
        : data.net(month, actual);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: summary('PLANNED GAIN / LOSS', net(false), dark: true),
          ),
          const SizedBox(width: 10),
          Expanded(child: summary('ACTUAL GAIN / LOSS', net(true))),
        ],
      ),
    );
  }

  Widget overview() => Column(
    children: [
      totals(),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 15, color: ink),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Read-only · swipe across for differences',
                style: TextStyle(fontSize: 12, color: ink),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: FrozenTable(
          headers: const ['Planned', 'Actual', 'Difference'],
          rows: [
            for (final income in [true, false]) ...[
              LedgerRow(income ? 'INCOME' : 'EXPENSES', [
                money(data.total(month, income, false)),
                money(data.total(month, income, true)),
                money(
                  (income ? 1 : -1) *
                      (data.total(month, income, true) -
                          data.total(month, income, false)),
                ),
              ], heading: true),
              for (final c in data.categories.where((c) => c.income == income))
                LedgerRow(c.name, [
                  money(data.planned(key, c.id)),
                  money(data.actual(month, c.id)),
                  money(
                    (income ? 1 : -1) *
                        (data.actual(month, c.id) - data.planned(key, c.id)),
                  ),
                ]),
            ],
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Positive difference = more income or less spending than planned.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ),
    ],
  );
  Future<void> editAmount(Category c) async {
    final controller = TextEditingController(
      text: (data.planned(key, c.id) / 100).toStringAsFixed(2),
    );
    String? error;
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Plan · ${c.name}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount for ${months[month.month - 1]}',
              prefixText: '\$ ',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = parseCents(controller.text);
                if (v == null) {
                  update(() => error = 'Enter an amount such as 125.50');
                } else {
                  Navigator.pop(ctx, v);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (amount != null) {
      final next = data.copy();
      next.plans.putIfAbsent(key, () => {})[c.id] = amount;
      await commit(next);
    }
  }

  Future<void> addCategory() async {
    final name = TextEditingController();
    bool income = false;
    String? error;
    final c = await showDialog<Category>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Add category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: 'Category name',
                  errorText: error,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Expense')),
                  ButtonSegment(value: true, label: Text('Income')),
                ],
                selected: {income},
                onSelectionChanged: (v) => update(() => income = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty ||
                    data.categories.any(
                      (c) => c.name.toLowerCase() == n.toLowerCase(),
                    )) {
                  update(() => error = 'Use a unique category name');
                  return;
                }
                Navigator.pop(
                  ctx,
                  Category(
                    DateTime.now().microsecondsSinceEpoch.toString(),
                    n,
                    income,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (c != null) {
      final next = data.copy();
      next.categories.add(c);
      await commit(next);
    }
  }

  Future<void> copyPrevious() async {
    final prev = monthKey(DateTime(month.year, month.month - 1));
    if ((data.plans[prev] ?? {}).isEmpty) {
      message('No plan in the previous month to copy.');
      return;
    }
    if (await confirm(
      'Copy previous month?',
      'This replaces this month’s planned amounts. Transactions stay as entered.',
    )) {
      final next = data.copy();
      next.plans[key] = Map.of(data.plans[prev]!);
      await commit(next);
    }
  }

  Widget planner() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: summary(
          'PLANNED GAIN / LOSS',
          data.net(month, false),
          dark: true,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: addCategory,
              icon: const Icon(Icons.add),
              label: const Text('Category'),
            ),
            TextButton.icon(
              onPressed: copyPrevious,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy prior month'),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          children: [
            for (final income in [true, false]) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Text(
                  income ? 'INCOME' : 'EXPENSES',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ink,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              for (final c in data.categories.where((c) => c.income == income))
                ListTile(
                  title: Text(c.name),
                  subtitle: const Text('Tap to change planned amount'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        money(data.planned(key, c.id)),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.edit_outlined, size: 18),
                    ],
                  ),
                  onTap: () => editAmount(c),
                ),
            ],
          ],
        ),
      ),
    ],
  );
  Future<void> transaction([Entry? existing]) async {
    String cat =
        existing?.category ?? data.categories.firstWhere((c) => !c.income).id;
    DateTime date =
        existing?.date ??
        (monthKey(DateTime.now()) == key ? DateTime.now() : month);
    final amount = TextEditingController(
      text: existing == null ? '' : (existing.cents / 100).toStringAsFixed(2),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    String? error;
    final entry = await showDialog<Entry>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            existing == null ? 'Add transaction' : 'Edit transaction',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in data.categories)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.income ? '+' : '−'} ${c.name}'),
                      ),
                  ],
                  onChanged: (v) => cat = v!,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100, 12, 31),
                    );
                    if (d != null) update(() => date = d);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    '${months[date.month - 1]} ${date.day}, ${date.year}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final cents = parseCents(amount.text);
                if (cents == null || cents == 0) {
                  update(() => error = 'Enter an amount greater than zero');
                  return;
                }
                Navigator.pop(
                  ctx,
                  Entry(
                    existing?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    cat,
                    date,
                    cents,
                    note.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (entry != null) {
      final next = data.copy();
      next.entries.removeWhere((e) => e.id == entry.id);
      next.entries.add(entry);
      if (await commit(next)) message('Transaction saved.');
    }
  }

  Widget transactions() {
    final entries = data.entries.where((e) => monthKey(e.date) == key).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => transaction(),
              icon: const Icon(Icons.add),
              label: const Text('Add income or expense'),
            ),
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 54, color: ink),
                        SizedBox(height: 16),
                        Text(
                          'A fresh start for this month',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add your income and spending here. Actual totals update automatically.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final c = data.categories.firstWhere(
                      (c) => c.id == e.category,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          c.income ? Icons.south_west : Icons.north_east,
                        ),
                      ),
                      title: Text(c.name),
                      subtitle: Text(
                        '${months[e.date.month - 1]} ${e.date.day}${e.note.isEmpty ? '' : ' · ${e.note}'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${c.income ? '+' : '−'}${money(e.cents)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await transaction(e);
                              } else if (await confirm(
                                'Delete transaction?',
                                'Remove ${money(e.cents)} from ${c.name}?',
                              )) {
                                final next = data.copy();
                                next.entries.removeWhere((x) => x.id == e.id);
                                await commit(next);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => transaction(e),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget yearly() => Column(
    children: [
      totals(annual: true),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '${month.year} · full calendar year · entered transactions only',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      Expanded(
        child: FrozenTable(
          headers: const [
            'Plan income',
            'Plan expenses',
            'Plan gain/loss',
            'Actual income',
            'Actual expenses',
            'Actual gain/loss',
          ],
          rows: [
            for (int i = 1; i <= 12; i++)
              LedgerRow(months[i - 1], [
                money(data.total(DateTime(month.year, i), true, false)),
                money(data.total(DateTime(month.year, i), false, false)),
                money(data.net(DateTime(month.year, i), false)),
                money(data.total(DateTime(month.year, i), true, true)),
                money(data.total(DateTime(month.year, i), false, true)),
                money(data.net(DateTime(month.year, i), true)),
              ]),
          ],
        ),
      ),
    ],
  );
  Future<void> backup() async {
    try {
      final ok = await bridge.invokeMethod<bool>(
        'export',
        jsonEncode(data.toJson()),
      );
      if (ok == true) message('Backup saved.');
    } catch (_) {
      message('Backup could not be saved.');
    }
  }

  Future<void> restore() async {
    if (!await confirm(
      'Restore a backup?',
      'Restoring replaces all current budgets and transactions. Save a backup of your current data first.',
    )) {
      return;
    }
    try {
      final raw = await bridge.invokeMethod<String>('import');
      if (raw == null) return;
      final next = BudgetData.decode(raw);
      if (await commit(next)) message('Backup restored.');
    } catch (_) {
      message('Could not restore. Choose a valid Month Ledger backup.');
    }
  }

  Widget settings() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Your budget, on your phone.',
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: ink),
      ),
      const SizedBox(height: 12),
      const Text(
        'Amounts use dollars and cents. Plans belong to individual months; entering a transaction changes actuals only. No bank connection or account is needed.',
      ),
      const SizedBox(height: 24),
      ListTile(
        leading: const Icon(Icons.save_alt),
        title: const Text('Save a backup'),
        subtitle: const Text('Choose where to keep your budget file'),
        onTap: backup,
      ),
      ListTile(
        leading: const Icon(Icons.restore),
        title: const Text('Restore a backup'),
        subtitle: const Text('Replace current data with a saved file'),
        onTap: restore,
      ),
      const SizedBox(height: 24),
      const Text(
        'Keep a backup before uninstalling or switching phones. Backup files contain your entries and are not encrypted. Categories are shared across months; planned amounts are independent. Savings is treated as a planned outgoing.',
      ),
      const SizedBox(height: 28),
      const Text(
        'Month Ledger · Version 1.0\nPersonal Android preview',
        style: TextStyle(color: Colors.black54),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    const titles = [
      'Monthly overview',
      'Edit budget',
      'Transactions',
      'Yearly summary',
      'Backup & help',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MONTH LEDGER',
              style: TextStyle(fontSize: 11, letterSpacing: 2),
            ),
            Text(
              titles[page],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
            ),
          ],
        ),
        actions: [
          if (page < 4)
            IconButton(
              tooltip: 'Current month',
              onPressed: () => setState(
                () =>
                    month = DateTime(DateTime.now().year, DateTime.now().month),
              ),
              icon: const Icon(Icons.today_outlined),
            ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Month Ledger',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
              ),
              for (int i = 0; i < titles.length; i++)
                ListTile(
                  selected: page == i,
                  leading: Icon(
                    [
                      Icons.dashboard_outlined,
                      Icons.edit_note,
                      Icons.receipt_long_outlined,
                      Icons.bar_chart,
                      Icons.settings_outlined,
                    ][i],
                  ),
                  title: Text(titles[i]),
                  onTap: () {
                    setState(() => page = i);
                    Navigator.pop(context);
                  },
                ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'A little clarity, every month.',
                  style: TextStyle(color: ink),
                ),
              ),
            ],
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadFailed
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Your saved data could not be opened. Close and reopen the app. Existing data has been preserved.',
                ),
              ),
            )
          : Column(
              children: [
                if (busy) const LinearProgressIndicator(minHeight: 2),
                if (page < 4) monthPicker(),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: busy,
                    child: [
                      overview,
                      planner,
                      transactions,
                      yearly,
                      settings,
                    ][page](),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page < 4 ? page : 0,
        onDestinationSelected: (i) => setState(() => page = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Overview',
          ),
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Plan'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Entries',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Year'),
        ],
      ),
    );
  }
}

class LedgerRow {
  final String label;
  final List<String> values;
  final bool heading;
  LedgerRow(this.label, this.values, {this.heading = false});
}

class FrozenTable extends StatefulWidget {
  final List<String> headers;
  final List<LedgerRow> rows;
  const FrozenTable({super.key, required this.headers, required this.rows});
  @override
  State<FrozenTable> createState() => _FrozenTableState();
}

class _FrozenTableState extends State<FrozenTable> {
  final horizontal = ScrollController(),
      left = ScrollController(),
      right = ScrollController();
  bool syncing = false;
  @override
  void initState() {
    super.initState();
    left.addListener(() => sync(left, right));
    right.addListener(() => sync(right, left));
  }

  void sync(ScrollController from, ScrollController to) {
    if (syncing || !to.hasClients) return;
    syncing = true;
    to.jumpTo(from.offset.clamp(0.0, to.position.maxScrollExtent));
    syncing = false;
  }

  @override
  void dispose() {
    horizontal.dispose();
    left.dispose();
    right.dispose();
    super.dispose();
  }

  Widget cell(
    String text,
    double width, {
    bool header = false,
    bool section = false,
    bool label = false,
  }) => Container(
    width: width,
    height: 60,
    alignment: label ? Alignment.centerLeft : Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: header
          ? ink
          : section
          ? const Color(0xffe4ece4)
          : Colors.white,
      border: const Border(bottom: BorderSide(color: Color(0xffe6e9e3))),
    ),
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        color: header ? Colors.white : ink,
        fontWeight: header || section ? FontWeight.bold : FontWeight.normal,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, box) {
      final w = (box.maxWidth * .35).clamp(100.0, 160.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: w,
            child: Column(
              children: [
                cell('Category / month', w, header: true, label: true),
                Expanded(
                  child: SingleChildScrollView(
                    controller: left,
                    child: Column(
                      children: [
                        for (final r in widget.rows)
                          cell(r.label, w, section: r.heading, label: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: horizontal,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: horizontal,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: widget.headers.length * 126.0,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final h in widget.headers)
                            cell(h, 126, header: true),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: right,
                          child: Column(
                            children: [
                              for (final r in widget.rows)
                                Row(
                                  children: [
                                    for (final v in r.values)
                                      cell(v, 126, section: r.heading),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
