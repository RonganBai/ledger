import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';

class ResetPasswordPage extends StatefulWidget {
  final VoidCallback? onDone;

  const ResetPasswordPage({super.key, this.onDone});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordCtrl.text),
      );
      AppLog.i('Auth', 'Password reset success');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Please login again.')),
      );
      widget.onDone?.call();
    } on AuthException catch (e) {
      AppLog.w('Auth', 'Password reset failed. ${e.message}');
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e, st) {
      AppLog.e('Auth', e, st);
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(
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
                            'Reset Password',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Set a new password for your account.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
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
                            onPressed: _submitting ? null : _submit,
                            icon: const Icon(Icons.check_circle_rounded),
                            label: Text(
                              _submitting ? 'Updating...' : 'Update password',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _submitting ? null : widget.onDone,
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
      ),
    );
  }
}
