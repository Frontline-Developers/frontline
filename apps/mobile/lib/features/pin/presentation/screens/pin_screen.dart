import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/pin_state.dart';
import '../providers/pin_provider.dart';

const _kMaxWidth = 400.0;

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pin = ref.watch(pinNotifierProvider);

    ref.listen<PinState>(pinNotifierProvider, (prev, next) {
      if (next.status == PinStatus.error && prev?.status != PinStatus.error) {
        _shakeController.forward(from: 0);
      }
    });

    if (pin.status == PinStatus.loading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (pin.status == PinStatus.biometricSetup) {
      return _BiometricSetupScreen();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(
          children: [
            if (pin.status == PinStatus.bypassWarning)
              const _BypassWarningBanner(),
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _kMaxWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _Logo(),
                            const SizedBox(height: 32),
                            _ModeTitle(status: pin.status),
                            const SizedBox(height: 24),
                            AnimatedBuilder(
                              animation: _shakeAnimation,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(_shakeAnimation.value, 0),
                                child: child,
                              ),
                              child: _DotRow(
                                filled: pin.digits.length,
                                hasError: pin.status == PinStatus.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _ErrorText(message: pin.errorMessage),
                            const SizedBox(height: 32),
                            if (pin.status != PinStatus.bypassWarning)
                              _Numpad(
                                showBiometric:
                                    pin.biometricAvailable &&
                                    pin.biometricEnabled,
                              ),
                            const SizedBox(height: 24),
                            _ForgotPinButton(status: pin.status),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 12),
        const Text(
          'FRONTLINE',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}

// ── Mode title ────────────────────────────────────────────────────────────────

class _ModeTitle extends StatelessWidget {
  final PinStatus status;
  const _ModeTitle({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      PinStatus.createPin => 'Create your PIN',
      PinStatus.confirmPin => 'Confirm your PIN',
      PinStatus.enterPin || PinStatus.error => 'Enter your PIN',
      PinStatus.bypassWarning => 'Security issue detected',
      _ => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();

    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Dot indicator ─────────────────────────────────────────────────────────────

class _DotRow extends StatelessWidget {
  final int filled;
  final bool hasError;

  const _DotRow({required this.filled, required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final isFilled = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: PinDot(filled: isFilled, hasError: hasError),
        );
      }),
    );
  }
}

/// A single dot in the PIN entry indicator. Public for widget testing.
class PinDot extends StatelessWidget {
  final bool filled;
  final bool hasError;

  const PinDot({super.key, required this.filled, required this.hasError});

  @override
  Widget build(BuildContext context) {
    final color = hasError || filled ? AppColors.accent : Colors.transparent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: filled || hasError
            ? null
            : Border.all(color: AppColors.divider, width: 1.5),
      ),
    );
  }
}

// ── Error text ────────────────────────────────────────────────────────────────

class _ErrorText extends StatelessWidget {
  final String? message;
  const _ErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        message!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────────────────────

class _Numpad extends ConsumerWidget {
  final bool showBiometric;
  const _Numpad({required this.showBiometric});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pinNotifierProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          _NumpadRow(digits: const [1, 2, 3], notifier: notifier),
          const SizedBox(height: 12),
          _NumpadRow(digits: const [4, 5, 6], notifier: notifier),
          const SizedBox(height: 12),
          _NumpadRow(digits: const [7, 8, 9], notifier: notifier),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: showBiometric
                    ? _BiometricButton(notifier: notifier)
                    : const SizedBox(),
              ),
              const SizedBox(width: 12),
              Expanded(child: _DigitButton(digit: 0, notifier: notifier)),
              const SizedBox(width: 12),
              Expanded(child: _BackspaceButton(notifier: notifier)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumpadRow extends StatelessWidget {
  final List<int> digits;
  final PinNotifier notifier;
  const _NumpadRow({required this.digits, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _DigitButton(digit: digits[i], notifier: notifier),
          ),
        ],
      ],
    );
  }
}

class _DigitButton extends StatelessWidget {
  final int digit;
  final PinNotifier notifier;
  const _DigitButton({required this.digit, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return _PadButton(
      onTap: () => notifier.appendDigit(digit),
      child: Text(
        '$digit',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  final PinNotifier notifier;
  const _BackspaceButton({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return _PadButton(
      onTap: notifier.backspace,
      child: const Icon(
        Icons.backspace_outlined,
        color: AppColors.textPrimary,
        size: 22,
      ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  final PinNotifier notifier;
  const _BiometricButton({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return _PadButton(
      key: const Key('pin_biometric_btn'),
      onTap: notifier.promptBiometrics,
      child: const Icon(
        Icons.fingerprint,
        color: AppColors.textPrimary,
        size: 26,
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _PadButton({super.key, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(height: 64, child: Center(child: child)),
      ),
    );
  }
}

// ── Bypass warning banner ────────────────────────────────────────────────────

class _BypassWarningBanner extends StatelessWidget {
  const _BypassWarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bypass_warning_banner'),
      color: Colors.amber[700],
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: const [
          Icon(Icons.warning_rounded, color: Colors.black87, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Browser storage was modified. Tap \'Forgot PIN\' to reset.',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Biometric setup screen ────────────────────────────────────────────────────

class _BiometricSetupScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pinNotifierProvider.notifier);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxWidth),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.fingerprint,
                      color: AppColors.accent,
                      size: 72,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Use biometrics to unlock?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You can unlock Frontline with your fingerprint or face '
                      'instead of typing your PIN each time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                              side: const BorderSide(color: AppColors.divider),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: notifier.skipBiometricSetup,
                            child: const Text('Skip'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: notifier.enableBiometric,
                            child: const Text('Enable'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Forgot PIN button ────────────────────────────────────────────────────────

class _ForgotPinButton extends ConsumerWidget {
  final PinStatus status;
  const _ForgotPinButton({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => _showResetDialog(context, ref),
      child: const Text(
        'Forgot PIN',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text(
          'Delete all app data?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will permanently erase your reports, bookmarks, and PIN. '
          'This cannot be undone.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(pinNotifierProvider.notifier).resetAll();
            },
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
  }
}
