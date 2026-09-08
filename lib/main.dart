import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'controllers/verification_controller.dart';
import 'services/compliance_service.dart';
import 'services/fake_compliance_api.dart';
import 'widgets/lsa_verification_screen.dart';

const bool kUseLiveApi = bool.fromEnvironment('LIVE_API');

void main() => runApp(const HabotConnectApp());

class HabotConnectApp extends StatefulWidget {
  const HabotConnectApp({super.key});

  @override
  State<HabotConnectApp> createState() => _HabotConnectAppState();
}

class _HabotConnectAppState extends State<HabotConnectApp> {
  late final VerificationController _controller = VerificationController(
    complianceService: ComplianceService(
      client: kUseLiveApi ? http.Client() : FakeComplianceApi(),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4338CA),
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.onSurface.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: border(scheme.outlineVariant),
        enabledBorder: border(scheme.outlineVariant),
        focusedBorder: border(scheme.primary, 1.6),
        helperMaxLines: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HabotConnect — LSA Verification',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: LsaVerificationScreen(
        controller: _controller,
        demoControls: !kUseLiveApi,
      ),
    );
  }
}
