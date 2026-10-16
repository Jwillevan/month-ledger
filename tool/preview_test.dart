import 'dart:convert';
import 'dart:io';


import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:month_ledger/main.dart';
import 'package:month_ledger/model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Phone overview preview', (tester) async {
    final textFont=FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(File('${Platform.environment['WINDIR']}/Fonts/segoeui.ttf').readAsBytesSync())));
    await textFont.load();
    final icons=FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
    await icons.load();
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now=DateTime.now();
    final demo=BudgetData.empty();
    demo.plans[monthKey(now)]={'salary':400000,'housing':140000,'groceries':50000,'utilities':18000,'savings':50000};
    demo.entries.addAll([Entry('1','salary',now,410000,''),Entry('2','housing',now,140000,''),Entry('3','groceries',now,54000,'')]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(bridge,(call)async=>call.method=='load'?jsonEncode(demo.toJson()):true);
    await tester.pumpWidget(const BudgetApp());
    await tester.pumpAndSettle();
    await expectLater(find.byType(BudgetApp),matchesGoldenFile('../preview.png'));
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(BudgetApp),matchesGoldenFile('../plan-preview.png'));
  });
}

