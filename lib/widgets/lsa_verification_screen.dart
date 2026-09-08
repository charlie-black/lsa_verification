import 'package:flutter/material.dart';

import '../controllers/verification_controller.dart';
import '../models/verification_status.dart';

class LsaVerificationScreen extends StatelessWidget {
  final VerificationController controller;
  final bool demoControls;

  const LsaVerificationScreen({
    super.key,
    required this.controller,
    this.demoControls = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final state = controller.state;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ScreenHeader(),
                      const SizedBox(height: 24),
                      _StatusBanner(
                          status: state.status, message: state.message),
                      const SizedBox(height: 24),
                      _FormCard(controller: controller),
                      const SizedBox(height: 24),
                      _SubmitButton(
                        enabled: state.submitEnabled,
                        loading:
                            state.status == VerificationStatus.processing,
                        onPressed: controller.submit,
                      ),
                      if (!state.submitEnabled) ...[
                        const SizedBox(height: 12),
                        _ResetSessionAction(
                            onPressed: controller.resetSession),
                      ],
                      if (demoControls) ...[
                        const SizedBox(height: 28),
                        _DemoPanel(controller: controller),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.verified_user_outlined,
              color: cs.onPrimaryContainer, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LSA Onboarding Gate',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'HabotConnect Data Compliance',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final VerificationStatus status;
  final String? message;

  const _StatusBanner({required this.status, this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color accent, IconData icon) = switch (status) {
      VerificationStatus.idle => (cs.onSurfaceVariant, Icons.schedule_outlined),
      VerificationStatus.processing => (cs.primary, Icons.autorenew),
      VerificationStatus.quarantined => (
          const Color(0xFFDC2626),
          Icons.gpp_bad_outlined
        ),
      VerificationStatus.success => (
          const Color(0xFF16A34A),
          Icons.verified_outlined
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: 0.10), cs.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: status == VerificationStatus.processing
                ? CircularProgressIndicator(strokeWidth: 2.4, color: accent)
                : Icon(icon, size: 22, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.bannerText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontSize: 14,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    message!,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final VerificationController controller;

  const _FormCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verification details',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          _LsaIdField(controller: controller.lsaIdController),
          const SizedBox(height: 18),
          _PredecessorIdField(value: controller.predecessorId),
          const SizedBox(height: 18),
          _ParentConsentCodeField(controller: controller),
        ],
      ),
    );
  }
}

class _LsaIdField extends StatelessWidget {
  final TextEditingController controller;

  const _LsaIdField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('lsa_id_field'),
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'lsa_id',
        helperText: 'Pre-filled learning support assistant identifier',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
    );
  }
}

class _PredecessorIdField extends StatelessWidget {
  final String? value;

  const _PredecessorIdField({required this.value});

  @override
  Widget build(BuildContext context) {
    final shown = value ?? '(missing — submission will be blocked)';
    return TextFormField(
      key: ValueKey('predecessor_id_field_$shown'),
      initialValue: shown,
      readOnly: true,
      enableInteractiveSelection: false,
      decoration: const InputDecoration(
        labelText: 'predecessor_id',
        helperText: 'System-issued lineage identifier · read-only',
        prefixIcon: Icon(Icons.lock_outline),
      ),
    );
  }
}

class _ParentConsentCodeField extends StatelessWidget {
  final VerificationController controller;

  const _ParentConsentCodeField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('parent_consent_code_field'),
      focusNode: controller.consentFocusNode,
      controller: controller.consentCodeController,
      onChanged: controller.onConsentChanged,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => controller.submit(),
      decoration: const InputDecoration(
        labelText: 'parent_consent_code',
        hintText: 'PCC-2026-9901',
        helperText: 'Enter the parent consent code',
        prefixIcon: Icon(Icons.vpn_key_outlined),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: (enabled && !loading) ? onPressed : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 10),
          ],
          const Text('Verify & Submit'),
        ],
      ),
    );
  }
}

class _ResetSessionAction extends StatelessWidget {
  final VoidCallback onPressed;

  const _ResetSessionAction({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Reset session'),
    );
  }
}

class _DemoPanel extends StatelessWidget {
  final VerificationController controller;

  const _DemoPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final orphan = controller.predecessorId == null;
    return Container(
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SwitchListTile(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text('Simulate orphan data'),
        subtitle: Text(orphan
            ? 'predecessor_id is null — submit will fail-closed'
            : 'predecessor_id = PRED-9982-XYZ'),
        value: orphan,
        onChanged: (v) => controller.debugSetLineagePresent(present: !v),
      ),
    );
  }
}
