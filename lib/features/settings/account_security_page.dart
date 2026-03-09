import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/tr.dart';
import 'settings_texts.dart';

class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Account Security'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: Text(st(context, 'Change Password')),
                  subtitle: Text(
                    st(context, 'Email verification required before update'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alternate_email_rounded),
                  title: Text(st(context, 'Change Bound Email')),
                  subtitle: Text(
                    st(context, 'Email verification required before update'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangeEmailPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationPanel extends StatelessWidget {
  final TextEditingController codeController;
  final bool sending;
  final bool verifying;
  final bool verified;
  final int resendCooldown;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;

  const _VerificationPanel({
    required this.codeController,
    required this.sending,
    required this.verifying,
    required this.verified,
    required this.resendCooldown,
    required this.onSendCode,
    required this.onVerifyCode,
  });

  String _resendText(BuildContext context, int seconds) {
    return tr(context, en: 'Resend in ${seconds}s', zh: '$seconds 秒后可重发');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: st(context, 'Email Verification Code'),
                prefixIcon: const Icon(Icons.verified_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sending || verified || resendCooldown > 0
                        ? null
                        : onSendCode,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      sending
                          ? st(context, 'Sending...')
                          : (resendCooldown > 0
                                ? _resendText(context, resendCooldown)
                                : st(context, 'Send Code')),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: verifying || verified ? null : onVerifyCode,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(
                      verifying
                          ? st(context, 'Verifying...')
                          : st(context, 'Verify'),
                    ),
                  ),
                ),
              ],
            ),
            if (verified) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    st(context, 'Verification passed'),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPwdCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _reauthenticating = false;
  bool _reauthenticated = false;
  bool _sending = false;
  bool _verifying = false;
  bool _saving = false;
  bool _verified = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  String? get _currentEmail => Supabase.instance.client.auth.currentUser?.email;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _currentPwdCtrl.dispose();
    _codeCtrl.dispose();
    _newPwdCtrl.dispose();
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

  Future<void> _reauthenticate() async {
    final email = _currentEmail;
    final pwd = _currentPwdCtrl.text;
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    if (pwd.isEmpty) {
      setState(() => _error = st(context, 'Please enter current password.'));
      return;
    }
    setState(() {
      _reauthenticating = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pwd,
      );
      if (!mounted) return;
      setState(() => _reauthenticated = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st(context, 'Session verified'))));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _reauthenticating = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_reauthenticated) {
      setState(() => _error = st(context, 'Please verify session first.'));
      return;
    }
    if (_resendCooldown > 0) return;
    final email = _currentEmail;
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      _startResendCooldown(180);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(st(context, 'Verification code sent to $email')),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _currentEmail;
    final code = _codeCtrl.text.trim();
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    if (code.length < 6) {
      setState(
        () => _error = st(context, 'Please enter a valid 6-digit code.'),
      );
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (!mounted) return;
      setState(() => _verified = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st(context, 'Email verified'))));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _save() async {
    final pwd = _newPwdCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (!_verified) {
      setState(
        () => _error = st(context, 'Please complete email verification first.'),
      );
      return;
    }
    if (!_reauthenticated) {
      setState(() => _error = st(context, 'Please verify session first.'));
      return;
    }
    if (pwd.length < 6) {
      setState(
        () => _error = st(context, 'Password must be at least 6 characters.'),
      );
      return;
    }
    if (pwd != confirm) {
      setState(() => _error = st(context, 'Passwords do not match.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pwd),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st(context, 'Password updated'))));
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _currentEmail ?? '-';
    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Change Password'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(st(context, 'Current bound email: $email')),
          const SizedBox(height: 12),
          TextField(
            controller: _currentPwdCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: st(context, 'Current Password'),
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _reauthenticating || _reauthenticated
                ? null
                : _reauthenticate,
            icon: const Icon(Icons.verified_user_rounded),
            label: Text(
              _reauthenticating
                  ? st(context, 'Verifying...')
                  : (_reauthenticated
                        ? st(context, 'Session verified')
                        : st(context, 'Verify Session')),
            ),
          ),
          const SizedBox(height: 12),
          _VerificationPanel(
            codeController: _codeCtrl,
            sending: _sending,
            verifying: _verifying,
            verified: _verified,
            resendCooldown: _resendCooldown,
            onSendCode: _sendCode,
            onVerifyCode: _verifyCode,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPwdCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: st(context, 'New Password'),
              prefixIcon: const Icon(Icons.lock_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: st(context, 'Confirm Password'),
              prefixIcon: const Icon(Icons.verified_user_rounded),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? st(context, 'Saving...')
                  : st(context, 'Update Password'),
            ),
          ),
        ],
      ),
    );
  }
}

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _currentPwdCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  bool _reauthenticating = false;
  bool _reauthenticated = false;
  bool _sending = false;
  bool _verifying = false;
  bool _saving = false;
  bool _verified = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  String? get _currentEmail => Supabase.instance.client.auth.currentUser?.email;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _currentPwdCtrl.dispose();
    _codeCtrl.dispose();
    _newEmailCtrl.dispose();
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

  Future<void> _reauthenticate() async {
    final email = _currentEmail;
    final pwd = _currentPwdCtrl.text;
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    if (pwd.isEmpty) {
      setState(() => _error = st(context, 'Please enter current password.'));
      return;
    }
    setState(() {
      _reauthenticating = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pwd,
      );
      if (!mounted) return;
      setState(() => _reauthenticated = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st(context, 'Session verified'))));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _reauthenticating = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_reauthenticated) {
      setState(() => _error = st(context, 'Please verify session first.'));
      return;
    }
    if (_resendCooldown > 0) return;
    final email = _currentEmail;
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      _startResendCooldown(180);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(st(context, 'Verification code sent to $email')),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _currentEmail;
    final code = _codeCtrl.text.trim();
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    if (code.length < 6) {
      setState(
        () => _error = st(context, 'Please enter a valid 6-digit code.'),
      );
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (!mounted) return;
      setState(() => _verified = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st(context, 'Email verified'))));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _save() async {
    final newEmail = _newEmailCtrl.text.trim();
    if (!_reauthenticated) {
      setState(() => _error = st(context, 'Please verify session first.'));
      return;
    }
    if (!_verified) {
      setState(
        () => _error = st(context, 'Please complete email verification first.'),
      );
      return;
    }
    if (!newEmail.contains('@')) {
      setState(() => _error = st(context, 'Please enter a valid email.'));
      return;
    }
    if (newEmail == (_currentEmail ?? '')) {
      setState(
        () => _error = st(context, 'New email cannot be the same as current.'),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            st(
              context,
              'Bound email update requested. Please check mailbox confirmation.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _currentEmail ?? '-';
    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Change Bound Email'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(st(context, 'Current bound email: $email')),
          const SizedBox(height: 12),
          TextField(
            controller: _currentPwdCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: st(context, 'Current Password'),
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _reauthenticating || _reauthenticated
                ? null
                : _reauthenticate,
            icon: const Icon(Icons.verified_user_rounded),
            label: Text(
              _reauthenticating
                  ? st(context, 'Verifying...')
                  : (_reauthenticated
                        ? st(context, 'Session verified')
                        : st(context, 'Verify Session')),
            ),
          ),
          const SizedBox(height: 12),
          _VerificationPanel(
            codeController: _codeCtrl,
            sending: _sending,
            verifying: _verifying,
            verified: _verified,
            resendCooldown: _resendCooldown,
            onSendCode: _sendCode,
            onVerifyCode: _verifyCode,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: st(context, 'New Email'),
              prefixIcon: const Icon(Icons.email_rounded),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? st(context, 'Saving...')
                  : st(context, 'Update Bound Email'),
            ),
          ),
        ],
      ),
    );
  }
}
