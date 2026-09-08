import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class FrictionLogger {
  static const Duration stallThreshold = Duration(seconds: 5);

  final void Function(String line) sink;

  FrictionLogger({void Function(String line)? sink})
      : sink = sink ?? _defaultSink;

  static void _defaultSink(String line) {
    debugPrint(line);
    developer.log(line, name: 'UI_FRICTION_LOG');
  }

  Timer? _timer;
  DateTime? _focusStartedAt;

  void startWatching(String fieldName) {
    _cancelTimer();
    _focusStartedAt = DateTime.now().toUtc();
    _timer = Timer(stallThreshold, () => _emitFrictionLog(fieldName));
  }

  void registerInteraction(String fieldName) => startWatching(fieldName);

  void stopWatching() {
    _cancelTimer();
    _focusStartedAt = null;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _emitFrictionLog(String fieldName) {
    final startedAt = _focusStartedAt;
    if (startedAt == null) return;

    final hesitationSeconds =
        DateTime.now().toUtc().difference(startedAt).inMilliseconds / 1000;

    sink(
      '[UI_FRICTION_LOG] Timestamp: ${_isoSeconds(DateTime.now())} | '
      'Field: $fieldName | '
      'Hesitation Duration: ${hesitationSeconds.toStringAsFixed(1)}s',
    );
  }

  static String _isoSeconds(DateTime dt) =>
      '${dt.toUtc().toIso8601String().split('.').first}Z';

  void dispose() => _cancelTimer();
}
