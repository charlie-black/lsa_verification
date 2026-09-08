import 'package:flutter/material.dart';

import '../exceptions/lineage_exception.dart';
import '../models/verification_status.dart';
import '../models/verification_view_state.dart';
import '../services/compliance_service.dart';
import '../services/friction_logger.dart';

class VerificationController extends ChangeNotifier {
  static const String defaultLsaId = 'LSA-7049';
  static const String systemPredecessorId = 'PRED-9982-XYZ';
  static const String consentFieldName = 'parent_consent_code';

  static const String quarantineFailureMessage =
      'Data Quarantined – Compliance Failure';

  final ComplianceService _complianceService;
  final FrictionLogger frictionLogger;

  final TextEditingController lsaIdController;

  final TextEditingController consentCodeController = TextEditingController();

  final FocusNode consentFocusNode = FocusNode(debugLabel: 'parent_consent_code');

  VerificationController({
    ComplianceService? complianceService,
    FrictionLogger? frictionLogger,
    String? lsaId,
    String? predecessorId = systemPredecessorId,
  })  : _complianceService = complianceService ?? ComplianceService(),
        frictionLogger = frictionLogger ?? FrictionLogger(),
        lsaIdController = TextEditingController(text: lsaId ?? defaultLsaId),
        _predecessorId = predecessorId {
    consentFocusNode.addListener(_handleConsentFocusChange);
  }

  VerificationViewState _state = VerificationViewState.initial();
  VerificationViewState get state => _state;

  String? _predecessorId;
  String? get predecessorId => _predecessorId;

  void _handleConsentFocusChange() {
    if (consentFocusNode.hasFocus) {
      frictionLogger.startWatching(consentFieldName);
    } else {
      frictionLogger.stopWatching();
    }
  }

  void consentFieldFocused() => frictionLogger.startWatching(consentFieldName);

  void consentFieldBlurred() => frictionLogger.stopWatching();

  void onConsentChanged(String _) =>
      frictionLogger.registerInteraction(consentFieldName);

  void debugSetLineagePresent({required bool present}) {
    _predecessorId = present ? systemPredecessorId : null;
    notifyListeners();
  }

  Future<void> submit() async {
    if (!_state.submitEnabled) return;

    frictionLogger.stopWatching();

    try {
      if (_predecessorId == null || _predecessorId!.trim().isEmpty) {
        throw const LineageException();
      }

      _emit(_state.copyWith(status: VerificationStatus.processing));

      final result = await _complianceService.verify(
        predecessorId: _predecessorId,
        lsaId: lsaIdController.text,
        parentConsentCode: consentCodeController.text,
      );

      _emit(VerificationViewState(
        status: VerificationStatus.success,
        message: 'Verified — compliance status: ${result['status']}',
        submitEnabled: true,
      ));
    } on LineageException catch (e) {
      _emit(VerificationViewState(
        status: VerificationStatus.quarantined,
        message: e.message,
        submitEnabled: true,
      ));
    } catch (_) {
      _purgeVolatileMemory();
      _resetFormState();
      _emit(const VerificationViewState(
        status: VerificationStatus.quarantined,
        message: quarantineFailureMessage,
        submitEnabled: false,
      ));
    }
  }

  void resetSession() {
    _predecessorId = systemPredecessorId;
    _resetFormState();
    frictionLogger.stopWatching();
    _emit(VerificationViewState.initial());
  }

  void _purgeVolatileMemory() {
    consentCodeController.clear();
    _predecessorId = null;
  }

  void _resetFormState() {
    consentCodeController.clear();
    lsaIdController.text = defaultLsaId;
  }

  void _emit(VerificationViewState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    consentFocusNode.removeListener(_handleConsentFocusChange);
    consentFocusNode.dispose();
    consentCodeController.dispose();
    lsaIdController.dispose();
    frictionLogger.dispose();
    _complianceService.dispose();
    super.dispose();
  }
}
