import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';

enum _ResetStep { requestCode, verifyCode, setPassword }

class ResetPasswordPage extends StatefulWidget {
  final String? initialEmail;
  final VoidCallback? onDone;

  const ResetPasswordPage({super.key, this.initialEmail, this.onDone});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  _ResetStep _step = _ResetStep.requestCode;
  bool _submitting = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = (widget.initialEmail ?? '').trim();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown([int seconds = 180]) {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() => _step = _ResetStep.verifyCode);
      _startResendCooldown(180);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent')),
      );
      AppLog.i('Auth', 'Reset OTP sent');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      AppLog.w('Auth', 'Reset OTP send failed. ${e.message}');
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      AppLog.e('Auth', e, st);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );
      if (!mounted) return;
      setState(() => _step = _ResetStep.setPassword);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code verified, please set a new password')),
      );
      AppLog.i('Auth', 'Reset OTP verified');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      AppLog.w('Auth', 'Reset OTP verify failed. ${e.message}');
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      AppLog.e('Auth', e, st);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordCtrl.text),
      );
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful. Please login.')),
      );
      AppLog.i('Auth', 'Password reset success (OTP flow)');
      widget.onDone?.call();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      AppLog.w('Auth', 'Password reset failed. ${e.message}');
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      AppLog.e('Auth', e, st);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _title() {
    switch (_step) {
      case _ResetStep.requestCode:
        return 'Reset Password';
      case _ResetStep.verifyCode:
        return 'Verify Code';
      case _ResetStep.setPassword:
        return 'Set New Password';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = insets > 0;
    return Scaffold(
      appBar: AppBar(title: Text(_title())),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: insets),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: keyboardVisible
                        ? Alignment.topCenter
                        : Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                          Text(
                            _title(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: _step != _ResetStep.requestCode,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (v) {
                              if (_step == _ResetStep.requestCode &&
                                  (v == null || !v.contains('@'))) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          if (_step != _ResetStep.requestCode) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _codeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Verification code',
                                prefixIcon: Icon(Icons.pin_rounded),
                              ),
                              validator: (v) {
                                if (_step == _ResetStep.verifyCode &&
                                    (v ?? '').trim().length < 6) {
                                  return 'Please enter the 6-digit code';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (_step == _ResetStep.setPassword) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'New password',
                                prefixIcon: Icon(Icons.lock_reset_rounded),
                              ),
                              validator: (v) {
                                final text = v ?? '';
                                if (text.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: Icon(Icons.verified_user_rounded),
                              ),
                              validator: (v) {
                                if ((v ?? '') != _passwordCtrl.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: cs.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _submitting
                                ? null
                                : () {
                                    switch (_step) {
                                      case _ResetStep.requestCode:
                                        _sendCode();
                                        break;
                                      case _ResetStep.verifyCode:
                                        _verifyCode();
                                        break;
                                      case _ResetStep.setPassword:
                                        _updatePassword();
                                        break;
                                    }
                                  },
                            icon: const Icon(Icons.check_circle_rounded),
                            label: Text(
                              _submitting
                                  ? 'Processing...'
                                  : (_step == _ResetStep.requestCode
                                        ? 'Send code'
                                        : _step == _ResetStep.verifyCode
                                        ? 'Verify code'
                                        : 'Update password'),
                            ),
                          ),
                          if (_step == _ResetStep.verifyCode) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed:
                                  (_submitting || _resendCooldown > 0)
                                  ? null
                                  : _sendCode,
                              child: Text(
                                _resendCooldown > 0
                                    ? 'Resend code in ${_resendCooldown}s'
                                    : 'Resend code',
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.of(context).maybePop(),
                            child: const Text('Back to login'),
                          ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
