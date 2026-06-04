import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../reporting/presentation/widgets/report_theme.dart';
import '../../domain/entities/pin_state.dart';
import '../providers/pin_provider.dart';

const _kMaxWidth = 400.0;

// ── Palette — matches the light theme used across all content screens ─────────

class _C {
  static const bg = ReportPalette.surface;
  static const card = Colors.white;
  static const navy = ReportPalette.navy;
  static const ink = ReportPalette.ink;
  static const inkSecondary = ReportPalette.inkSecondary;
  static const inkTertiary = ReportPalette.inkTertiary;
  static const hairline = ReportPalette.hairline;
  static const hairlineStrong = ReportPalette.hairlineStrong;
  static const error = AppColors.reportDisputed;
  static const amberBg = Color(0xFFFEF3C7);
  static const amberInk = Color(0xFF92400E);
}

// ── Key mapping for physical/virtual keyboard ─────────────────────────────────

int? _digitFromKey(LogicalKeyboardKey key) {
  final map = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.digit0: 0,
    LogicalKeyboardKey.numpad0: 0,
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad9: 9,
  };
  return map[key];
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // Tracks which numpad key is visually "pressed" by a keyboard event.
  final _highlightedDigit = ValueNotifier<int?>(null);

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
    _highlightedDigit.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _flashDigit(int digit) {
    _highlightedDigit.value = digit;
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _highlightedDigit.value = null;
    });
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final notifier = ref.read(pinNotifierProvider.notifier);
    final digit = _digitFromKey(event.logicalKey);
    if (digit != null) {
      notifier.appendDigit(digit);
      _flashDigit(digit);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      notifier.backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
        backgroundColor: _C.bg,
        body: Center(child: CircularProgressIndicator(color: _C.navy)),
      );
    }

    if (pin.status == PinStatus.biometricSetup) {
      return _BiometricSetupScreen();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Scaffold(
          backgroundColor: _C.bg,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 40,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _Logo(),
                              const SizedBox(height: 32),
                              _ModeTitle(status: pin.status),
                              const SizedBox(height: 8),
                              _ModeSubtitle(status: pin.status),
                              const SizedBox(height: 32),
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
                              const SizedBox(height: 6),
                              _ErrorText(message: pin.errorMessage),
                              const SizedBox(height: 32),
                              if (pin.status != PinStatus.bypassWarning)
                                _Numpad(
                                  showBiometric:
                                      pin.biometricAvailable &&
                                      pin.biometricEnabled,
                                  highlightedDigit: _highlightedDigit,
                                ),
                              const SizedBox(height: 24),
                              const _ForgotPinButton(),
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
      ),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'FRONTLINE',
      style: TextStyle(
        color: _C.ink,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
      ),
    );
  }
}

// ── Mode title & subtitle ─────────────────────────────────────────────────────

class _ModeTitle extends StatelessWidget {
  final PinStatus status;
  const _ModeTitle({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      PinStatus.createPin => 'Create your PIN',
      PinStatus.confirmPin => 'Confirm your PIN',
      PinStatus.enterPin || PinStatus.error => 'Enter your PIN',
      PinStatus.bypassWarning => 'Security issue',
      _ => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _C.ink,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.15,
      ),
    );
  }
}

class _ModeSubtitle extends StatelessWidget {
  final PinStatus status;
  const _ModeSubtitle({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      PinStatus.createPin => 'Choose 6 digits to protect your data',
      PinStatus.confirmPin => 'Enter the same 6 digits again',
      PinStatus.enterPin || PinStatus.error => 'Your data is protected',
      PinStatus.bypassWarning => 'Tap \'Forgot PIN\' below to reset.',
      _ => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _C.inkTertiary, fontSize: 13, height: 1.4),
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
    final active = filled || hasError;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: active ? (hasError ? _C.error : _C.navy) : Colors.transparent,
        shape: BoxShape.circle,
        border: active
            ? null
            : Border.all(color: _C.hairlineStrong, width: 1.5),
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
    if (message == null) return const SizedBox(height: 18);
    return Text(
      message!,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _C.error,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────────────────────

class _Numpad extends ConsumerWidget {
  final bool showBiometric;
  final ValueNotifier<int?> highlightedDigit;

  const _Numpad({required this.showBiometric, required this.highlightedDigit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pinNotifierProvider.notifier);

    return Column(
      children: [
        _NumpadRow(
          digits: const [1, 2, 3],
          notifier: notifier,
          highlight: highlightedDigit,
        ),
        const SizedBox(height: 10),
        _NumpadRow(
          digits: const [4, 5, 6],
          notifier: notifier,
          highlight: highlightedDigit,
        ),
        const SizedBox(height: 10),
        _NumpadRow(
          digits: const [7, 8, 9],
          notifier: notifier,
          highlight: highlightedDigit,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: showBiometric
                  ? _BiometricButton(notifier: notifier)
                  : const SizedBox(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DigitButton(
                digit: 0,
                notifier: notifier,
                highlight: highlightedDigit,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _BackspaceButton(notifier: notifier)),
          ],
        ),
      ],
    );
  }
}

class _NumpadRow extends StatelessWidget {
  final List<int> digits;
  final PinNotifier notifier;
  final ValueNotifier<int?> highlight;
  const _NumpadRow({
    required this.digits,
    required this.notifier,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _DigitButton(
              digit: digits[i],
              notifier: notifier,
              highlight: highlight,
            ),
          ),
        ],
      ],
    );
  }
}

class _DigitButton extends StatelessWidget {
  final int digit;
  final PinNotifier notifier;
  final ValueNotifier<int?> highlight;

  const _DigitButton({
    required this.digit,
    required this.notifier,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: highlight,
      builder: (_, active, _) => _PadButton(
        onTap: () => notifier.appendDigit(digit),
        pressed: active == digit,
        child: Text(
          '$digit',
          style: const TextStyle(
            color: _C.ink,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
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
        color: _C.inkSecondary,
        size: 20,
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
      child: const Icon(Icons.fingerprint, color: _C.navy, size: 24),
    );
  }
}

class _PadButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final bool pressed;

  const _PadButton({
    super.key,
    required this.onTap,
    required this.child,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      decoration: BoxDecoration(
        color: pressed ? ReportPalette.navySoft : _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pressed
              ? ReportPalette.navy.withValues(alpha: 0.3)
              : _C.hairline,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(height: 60, child: Center(child: child)),
        ),
      ),
    );
  }
}

// ── Bypass warning banner ─────────────────────────────────────────────────────

class _BypassWarningBanner extends StatelessWidget {
  const _BypassWarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bypass_warning_banner'),
      color: _C.amberBg,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: const [
          Icon(Icons.warning_rounded, color: _C.amberInk, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Browser storage was modified. Tap \'Forgot PIN\' to reset.',
              style: TextStyle(
                color: _C.amberInk,
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

// ── Forgot PIN button ─────────────────────────────────────────────────────────

class _ForgotPinButton extends ConsumerWidget {
  const _ForgotPinButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => _showResetDialog(context, ref),
      child: const Text(
        'Forgot PIN',
        style: TextStyle(
          color: _C.inkTertiary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete all app data?',
          style: TextStyle(
            color: _C.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will permanently erase your reports, bookmarks, and PIN. '
          'This cannot be undone.',
          style: TextStyle(color: _C.inkSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _C.inkTertiary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.reportDisputed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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

// ── Biometric setup screen ────────────────────────────────────────────────────

class _BiometricSetupScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pinNotifierProvider.notifier);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxWidth),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: ReportPalette.navySoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: _C.navy,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Use biometrics to unlock?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _C.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You can unlock Frontline with your fingerprint or face '
                      'instead of typing your PIN each time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _C.inkSecondary,
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
                              foregroundColor: _C.inkTertiary,
                              side: BorderSide(color: _C.hairline),
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
                              backgroundColor: _C.navy,
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
