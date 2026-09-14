import 'dart:ui' show Tristate;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:dart_pdf_editor/src/shell_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPhone(
    WidgetTester tester,
    Widget child, {
    double textScale = 2,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pdf-shell-controls')));
    await tester.pumpAndSettle();
  }

  testWidgets(
      '375px at 200% text opens Controls and Properties without clipping',
      (tester) async {
    await pumpPhone(tester, PdfEditorView(bytes: buildMultiPagePdf(2)));
    expect(tester.takeException(), isNull);
    expect(find.text('Controls'), findsOneWidget);

    final properties =
        find.byKey(const ValueKey('pdf-shell-properties-toggle'));
    await tester.ensureVisible(properties);
    await tester.pumpAndSettle();
    final label = find.descendant(of: properties, matching: find.byType(Text));
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.textScaler.scale(11), 22,
        reason: 'the control must respect the requested text size');

    await tester.tap(properties);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PdfAnnotationPropertiesPanel), findsOneWidget);
    expect(find.text('Controls'), findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('pdf-shell-properties-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.byType(PdfAnnotationPropertiesPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('control selection and disabled semantics at ${textScale}x',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var selectedCalls = 0;
      var disabledCalls = 0;
      await pumpPhone(
        tester,
        PdfShellBar(
          leading: const [],
          trailing: const [],
          compactControls: [
            PdfShellControlItem(
              key: const ValueKey('selected-control'),
              icon: Icons.view_agenda,
              label: 'Selected view with a longer descriptive title',
              selected: true,
              onPressed: () => selectedCalls++,
            ),
            PdfShellControlItem(
              key: const ValueKey('disabled-control'),
              icon: Icons.save_outlined,
              label: 'Save',
              enabled: false,
              onPressed: () => disabledCalls++,
            ),
          ],
        ),
        textScale: textScale,
      );
      expect(tester.takeException(), isNull);
      final selected = find.byKey(const ValueKey('selected-control'));
      final disabled = find.byKey(const ValueKey('disabled-control'));
      final selectedFlags = tester.getSemantics(selected).flagsCollection;
      expect(selectedFlags.isButton, isTrue);
      expect(selectedFlags.isSelected, Tristate.isTrue);
      expect(selectedFlags.isEnabled, Tristate.isTrue);
      expect(tester.getSemantics(disabled).flagsCollection.isEnabled,
          Tristate.isFalse);

      if (textScale == 1) {
        expect(find.byType(GridView), findsOneWidget,
            reason: 'normal text keeps the existing compact layout');
      } else {
        final label =
            find.descendant(of: selected, matching: find.byType(Text));
        expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
            isFalse);
      }
      await tester.tap(disabled);
      await tester.pumpAndSettle();
      expect(disabledCalls, 0);
      expect(find.text('Controls'), findsOneWidget);
      await tester.tap(selected);
      await tester.pumpAndSettle();
      expect(selectedCalls, 1);
      expect(find.text('Controls'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
