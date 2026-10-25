import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'luxury.dart';

/// Branded lock screen. Prompts automatically and allows the device
/// PIN/pattern as a fallback so the doctor can never be locked out of the
/// data when biometrics change or fail.
class LockScreen extends StatefulWidget {
  final bool arabic;
  final VoidCallback onUnlocked, onAuthStart, onAuthEnd;
  const LockScreen({
    super.key,
    required this.arabic,
    required this.onUnlocked,
    required this.onAuthStart,
    required this.onAuthEnd,
  });
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool busy = false;
  String? message;
  String tr(String ar, String en) => widget.arabic ? ar : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unlock());
  }

  Future<void> unlock() async {
    if (busy) return;
    busy = true;
    widget.onAuthStart();
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: tr('فتح ملف العيادة', 'Unlock clinic'),
        biometricOnly: false,
      );
      if (ok) {
        widget.onUnlocked();
      } else if (mounted) {
        setState(() => message = null);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = tr(
            'تعذّر التحقق. حاول مجدداً.',
            'Verification failed. Try again.',
          ),
        );
      }
    } finally {
      busy = false;
      widget.onAuthEnd();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: navy,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/brand_icon.png', height: 116),
              ),
              const SizedBox(height: 24),
              const Text(
                'Dr. Ahmad Tarraf',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('الملفات محمية', 'Your files are protected'),
                style: const TextStyle(color: silver),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: navy,
                ),
                icon: const Icon(Icons.lock_open_rounded),
                label: Text(tr('فتح العيادة', 'Unlock clinic')),
                onPressed: unlock,
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message!, style: const TextStyle(color: Colors.white70)),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
