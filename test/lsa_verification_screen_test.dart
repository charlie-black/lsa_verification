import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lsa_verification/controllers/verification_controller.dart';
import 'package:lsa_verification/services/compliance_service.dart';
import 'package:lsa_verification/services/friction_logger.dart';
import 'package:lsa_verification/widgets/lsa_verification_screen.dart';

VerificationController _controller(
  MockClient client, {
  void Function(String)? frictionSink,
}) =>
    VerificationController(
      complianceService: ComplianceService(client: client),
      frictionLogger: FrictionLogger(sink: frictionSink ?? (_) {}),
    );

Future<void> _pump(WidgetTester tester, VerificationController c) {
  return tester.pumpWidget(
    MaterialApp(home: LsaVerificationScreen(controller: c)),
  );
}

void main() {
  testWidgets('renders header, fields, prefilled values and the button',
      (tester) async {
    final c = _controller(MockClient((_) async => http.Response('{}', 200)));
    addTearDown(c.dispose);
    await _pump(tester, c);

    expect(find.text('LSA Onboarding Gate'), findsWidgets);
    expect(find.text('HabotConnect Data Compliance'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('LSA-7049'), findsOneWidget);
    expect(find.text('PRED-9982-XYZ'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verify & Submit'), findsOneWidget);

    final lsaField =
        tester.widget<TextField>(find.byKey(const Key('lsa_id_field')));
    expect(lsaField.readOnly, isFalse);
    expect(lsaField.controller!.text, 'LSA-7049');

    final readOnlyFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((f) => f.readOnly)
        .toList();
    expect(readOnlyFields, hasLength(1));
  });

  testWidgets('Case 1: valid submit drives the banner to Success', (tester) async {
    final c = _controller(
      MockClient((_) async => http.Response('{"status":"verified"}', 200)),
    );
    addTearDown(c.dispose);
    await _pump(tester, c);

    await tester.enterText(
        find.byKey(const Key('parent_consent_code_field')), 'PCC-2026-9901');
    final submit = find.widgetWithText(FilledButton, 'Verify & Submit');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Success'), findsOneWidget);
  });

  testWidgets('Case 3: null response locks the button and shows a Reset action',
      (tester) async {
    final c = _controller(
      MockClient((_) async => http.Response('{"status": null}', 200)),
    );
    addTearDown(c.dispose);
    await _pump(tester, c);

    await tester.enterText(
        find.byKey(const Key('parent_consent_code_field')), 'PCC-2026-9901');
    final submit = find.widgetWithText(FilledButton, 'Verify & Submit');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Quarantined (Fail-Closed)'), findsOneWidget);
    expect(find.text(VerificationController.quarantineFailureMessage),
        findsOneWidget);
    expect(VerificationController.quarantineFailureMessage,
        'Data Quarantined – Compliance Failure');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('parent_consent_code_field')))
          .controller!
          .text,
      isEmpty,
    );

    await tester.ensureVisible(find.text('Reset session'));
    await tester.tap(find.text('Reset session'));
    await tester.pumpAndSettle();
    expect(find.text('Idle'), findsOneWidget);
  });

  testWidgets('focusing parent_consent_code and idling over 5s emits a friction log',
      (tester) async {
    final logs = <String>[];
    final c = _controller(
      MockClient((_) async => http.Response('{}', 200)),
      frictionSink: logs.add,
    );
    addTearDown(c.dispose);
    await _pump(tester, c);

    await tester.tap(find.byKey(const Key('parent_consent_code_field')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    expect(logs, isEmpty, reason: 'not yet past the 5s threshold');

    await tester.pump(const Duration(seconds: 3));
    expect(logs, hasLength(1));
    expect(
      logs.single,
      matches(RegExp(
        r'^\[UI_FRICTION_LOG\] Timestamp: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z'
        r' \| Field: parent_consent_code'
        r' \| Hesitation Duration: \d+\.\d+s$',
      )),
    );
  });

  testWidgets('typing within 5s suppresses the friction log', (tester) async {
    final logs = <String>[];
    final c = _controller(
      MockClient((_) async => http.Response('{}', 200)),
      frictionSink: logs.add,
    );
    addTearDown(c.dispose);
    await _pump(tester, c);

    await tester.tap(find.byKey(const Key('parent_consent_code_field')));
    await tester.pump(const Duration(seconds: 4));
    await tester.enterText(
        find.byKey(const Key('parent_consent_code_field')), 'P');
    await tester.pump(const Duration(seconds: 4));

    expect(logs, isEmpty);

    c.consentFocusNode.unfocus();
    await tester.pump();
  });
}
