import 'dart:convert';

String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';
int? parseCents(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
}

class Category {
  final String id, name;
  final bool income;
  Category(this.id, this.name, this.income);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'income': income};
}

class Entry {
  final String id, category, note;
  final DateTime date;
  final int cents;
  Entry(this.id, this.category, this.date, this.cents, this.note);
  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'date': date.toIso8601String(),
    'cents': cents,
    'note': note,
  };
}

class BudgetData {
  final List<Category> categories;
  final Map<String, Map<String, int>> plans;
  final List<Entry> entries;
  BudgetData(this.categories, this.plans, this.entries);
  factory BudgetData.empty() => BudgetData(
    [
      Category('salary', 'Salary', true),
      Category('other-income', 'Other income', true),
      for (final n in [
        'Housing',
        'Utilities',
        'Groceries',
        'Transport',
        'Insurance',
        'Health',
        'Debt payments',
        'Savings',
        'Dining out',
        'Entertainment',
        'Personal',
        'Other expenses',
      ])
        Category(n.toLowerCase().replaceAll(' ', '-'), n, false),
    ],
    {},
    [],
  );
  int planned(String month, String category) => plans[month]?[category] ?? 0;
  int actual(DateTime month, String category) => entries
      .where(
        (e) => e.category == category && monthKey(e.date) == monthKey(month),
      )
      .fold(0, (a, e) => a + e.cents);
  int total(DateTime month, bool income, bool isActual) => categories
      .where((c) => c.income == income)
      .fold(
        0,
        (a, c) =>
            a +
            (isActual ? actual(month, c.id) : planned(monthKey(month), c.id)),
      );
  int net(DateTime month, bool actual) =>
      total(month, true, actual) - total(month, false, actual);
  Map<String, dynamic> toJson() => {
    'version': 1,
    'categories': categories.map((c) => c.toJson()).toList(),
    'plans': plans,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
  BudgetData copy() => decode(jsonEncode(toJson()));
  static BudgetData decode(String raw) {
    if (raw.length > 10000000) throw const FormatException('Backup too large');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1) throw const FormatException('Unknown version');
    final cats = (j['categories'] as List)
        .map(
          (c) => Category(
            c['id'] as String,
            c['name'] as String,
            c['income'] as bool,
          ),
        )
        .toList();
    final ids = cats.map((c) => c.id).toSet();
    if (cats.isEmpty ||
        ids.length != cats.length ||
        !cats.any((c) => !c.income) ||
        cats.any(
          (c) => c.name.trim().isEmpty || c.name.length > 50 || c.id.isEmpty,
        )) {
      throw const FormatException('Invalid categories');
    }
    final plans = <String, Map<String, int>>{};
    for (final p in (j['plans'] as Map).entries) {
      if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(p.key as String)) {
        throw const FormatException('Invalid month');
      }
      plans[p.key] = {};
      for (final v in (p.value as Map).entries) {
        if (!ids.contains(v.key) ||
            v.value is! int ||
            v.value < 0 ||
            v.value > 99999999999) {
          throw const FormatException('Invalid amount');
        }
        plans[p.key]![v.key as String] = v.value as int;
      }
    }
    final entries = (j['entries'] as List)
        .map(
          (e) => Entry(
            e['id'] as String,
            e['category'] as String,
            DateTime.parse(e['date'] as String),
            e['cents'] as int,
            e['note'] as String,
          ),
        )
        .toList();
    if (entries.map((e) => e.id).toSet().length != entries.length ||
        entries.any(
          (e) =>
              !ids.contains(e.category) ||
              e.cents <= 0 ||
              e.cents > 99999999999 ||
              e.date.year < 2000 ||
              e.date.year > 2100 ||
              e.note.length > 100,
        )) {
      throw const FormatException('Invalid transaction');
    }
    return BudgetData(cats, plans, entries);
  }
}
