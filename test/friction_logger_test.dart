import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsa_verification/services/friction_logger.dart';

void main() {
  group('FrictionLogger UI friction logging', () {
    test('emits a friction log after > 5s of hesitation on focus', () {
      fakeAsync((async) {
        final lines = <String>[];
        final logger = FrictionLogger(sink: lines.add);

        logger.startWatching('parent_consent_code');
        async.elapse(const Duration(seconds: 6));

        expect(lines, hasLength(1));
        expect(
          lines.single,
          matches(RegExp(
            r'^\[UI_FRICTION_LOG\] Timestamp: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z'
            r' \| Field: parent_consent_code'
            r' \| Hesitation Duration: \d+\.\d+s$',
          )),
        );

        logger.dispose();
      });
    });

    test('no log if the user types before 5s (interaction resets the clock)', () {
      fakeAsync((async) {
        final lines = <String>[];
        final logger = FrictionLogger(sink: lines.add);

        logger.startWatching('parent_consent_code');
        async.elapse(const Duration(seconds: 4));
        logger.registerInteraction('parent_consent_code');
        async.elapse(const Duration(seconds: 4));

        expect(lines, isEmpty);
        logger.dispose();
      });
    });

    test('no log if the field is blurred before the threshold', () {
      fakeAsync((async) {
        final lines = <String>[];
        final logger = FrictionLogger(sink: lines.add);

        logger.startWatching('parent_consent_code');
        async.elapse(const Duration(seconds: 3));
        logger.stopWatching();
        async.elapse(const Duration(seconds: 10));

        expect(lines, isEmpty);
        logger.dispose();
      });
    });
  });
}
