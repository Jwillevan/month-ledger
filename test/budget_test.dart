import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:month_ledger/main.dart';
import 'package:month_ledger/model.dart';

void main() {
  test(
    'Exact cents, validation, monthly and annual accounting survive backup',
    () {
      expect(parseCents('0.29'), 29);
      expect(parseCents('12.3'), 1230);
      for (final text in ['-1', '1.001', 'NaN', '', '1e4']) {
        expect(parseCents(text), isNull);
      }
      final d = BudgetData.empty();
      d.plans['2026-10'] = {'salary': 400000, 'housing': 150000};
      d.plans['2026-11'] = {'salary': 300000, 'housing': 150000};
      d.entries.addAll([
        Entry('1', 'salary', DateTime(2026, 10, 3), 410000, ''),
        Entry('2', 'housing', DateTime(2026, 10, 5), 155000, ''),
        Entry('3', 'housing', DateTime(2026, 11, 5), 150000, ''),
      ]);
      expect(d.net(DateTime(2026, 10), false), 250000);
      expect(d.net(DateTime(2026, 10), true), 255000);
      expect(d.net(DateTime(2026, 11), true), -150000);
      expect(
        List.generate(
          12,
          (i) => d.net(DateTime(2026, i + 1), false),
        ).fold<int>(0, (a, b) => a + b),
        400000,
      );
      final restored = BudgetData.decode(jsonEncode(d.toJson()));
      expect(restored.net(DateTime(2026, 10), true), 255000);
      final copy = d.copy();
      copy.plans['2026-10']!['housing'] = 0;
      expect(d.planned('2026-10', 'housing'), 150000);
      final invalid = d.toJson();
      invalid['entries'] = [
        Entry('bad', 'missing', DateTime(2026), 100, '').toJson(),
      ];
      expect(
        () => BudgetData.decode(jsonEncode(invalid)),
        throwsFormatException,
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          bridge,
          (call) async => call.method == 'load' ? null : true,
        );
  });
  testWidgets(
    'Plan and entry update actuals separately and survive reopening',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? saved;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, (call) async {
            if (call.method == 'load') return saved;
            if (call.method == 'save') {
              saved = call.arguments as String;
              return true;
            }
            return null;
          });
      await tester.pumpWidget(const BudgetApp());
      await tester.pumpAndSettle();
      expect(find.text('Monthly overview'), findsOneWidget);
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salary'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('\$4000.00'), findsWidgets);
      await tester.tap(find.text('Entries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add income or expense'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '125.50');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('−\$125.50'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const BudgetApp());
      await tester.pumpAndSettle();
      expect(find.text('\$4000.00'), findsWidgets);
      expect(find.text('-\$125.50'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Headers and category column remain fixed while scrolling either way',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:SizedBox(height:280,child:FrozenTable(headers:const ['Planned','Actual','Difference'],rows:[for(int i=0;i<12;i++) LedgerRow('Category $i',['Plan $i','Actual $i','Diff $i'])])))));
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.text('Category / month'));
      final rowBefore=tester.getTopLeft(find.text('Category 2'));
      await tester.dragFrom(const Offset(60, 210), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Category / month')), before);
      expect(tester.getTopLeft(find.text('Category 2')).dy,lessThan(rowBefore.dy));
      expect(tester.getCenter(find.text('Category 2')).dy,tester.getCenter(find.text('Plan 2')).dy);
      final dataX=tester.getTopLeft(find.text('Plan 2')).dx;
      await tester.drag(find.text('Actual').first, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Category / month')), before);
      expect(tester.getTopLeft(find.text('Plan 2')).dx,lessThan(dataX));
      expect(tester.getTopLeft(find.text('Category 2')).dx,rowBefore.dx);
      expect(tester.takeException(), isNull);
    },
  );
}


