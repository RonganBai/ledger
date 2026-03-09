import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';
import 'auth_local_prefs.dart';
import 'auth_redirect.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onToggleLocale;
  final Locale? locale;
  final Future<void> Function()? onContinueAsGuest;

  const LoginPage({
    super.key,
    this.onToggleLocale,
    this.locale,
    this.onContinueAsGuest,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoginMode = true;
  bool _autoLogin30Days = false;
  bool _submitting = false;
  String? _error;
  List<String> _rememberedEmails = const <String>[];

  bool get _isZh =>
      (widget.locale?.languageCode ??
          Localizations.localeOf(context).languageCode) ==
      'zh';

  String _t(String en, String zh) => _isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    _loadLocalAuthPrefs();
  }

  Future<void> _loadLocalAuthPrefs() async {
    final data = await AuthLocalPrefs.read();
    if (!mounted) return;
    setState(() {
      _autoLogin30Days = data.autoLoginEnabled;
      _rememberedEmails = data.rememberedEmails;
      if ((data.lastEmail ?? '').isNotEmpty) {
        _emailCtrl.text = data.lastEmail!;
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    try {
      final email = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(_t('Reset Password', '重置密码')),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _t('Registered email', '注册邮箱'),
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_t('Cancel', '取消')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
                child: Text(_t('Send reset email', '发送重置邮件')),
              ),
            ],
          );
        },
      );
      if (email == null || email.isEmpty) return;
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kAuthRecoveryRedirectTo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Reset email sent', '重置邮件已发送'))),
      );
      AppLog.i('Auth', 'Reset password email sent');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('Failed', '失败')}: ${e.message}')),
      );
      AppLog.w('Auth', 'Reset password failed. ${e.message}');
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${_t('Failed', '失败')}: $e')));
      AppLog.e('Auth', e, st);
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _openOtpResetPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordPage(initialEmail: _emailCtrl.text.trim()),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final auth = Supabase.instance.client.auth;
    final email = _emailCtrl.text.trim();
    AppLog.i('Auth', '${_isLoginMode ? 'SignIn' : 'SignUp'} attempt');

    try {
      if (_isLoginMode) {
        await auth.signInWithPassword(
          email: email,
          password: _passwordCtrl.text,
        );
        await AuthLocalPrefs.recordSuccessfulLogin(
          email: email,
          autoLogin30Days: _autoLogin30Days,
        );
        AppLog.i('Auth', 'SignIn success');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_t('Login success', '登录成功'))));
      } else {
        final response = await auth.signUp(
          email: email,
          password: _passwordCtrl.text,
          emailRedirectTo: kAuthEmailRedirectTo,
        );
        final verified = response.user?.emailConfirmedAt != null;
        if (!verified) {
          await auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  'Verification email sent. Please verify your email before logging in.',
                  '验证邮件已发送，请先完成邮箱验证后再登录。',
                ),
              ),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('Sign up success', '注册成功'))),
          );
        }
        AppLog.i(
          'Auth',
          'SignUp success. emailVerified=$verified',
        );
      }
    } on AuthException catch (e) {
      AppLog.w(
        'Auth',
        '${_isLoginMode ? 'SignIn' : 'SignUp'} failed. ${e.message}',
      );
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

  Future<void> _continueAsGuest() async {
    if (_submitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Continue as Guest', '访客使用')),
        content: Text(
          _t(
            'Guest data cannot use cross-platform sync. Upload/download and account password/email changes will be disabled.',
            '访客使用数据无法享受多平台数据互通，且上传/下载与账户密码邮箱修改功能将停用。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('Confirm', '确定')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onContinueAsGuest?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final modeColor = _isLoginMode ? cs.primary : Colors.teal;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = insets > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [modeColor.withValues(alpha: 0.14), cs.surface, cs.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: insets),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 36,
                    ),
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
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: modeColor.withValues(
                                            alpha: 0.16,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          _isLoginMode
                                              ? Icons.login_rounded
                                              : Icons.app_registration_rounded,
                                          color: modeColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _isLoginMode
                                              ? _t('Login Ledger', '登录 Ledger')
                                              : _t(
                                                  'Sign Up Ledger',
                                                  '注册 Ledger',
                                                ),
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      SegmentedButton<String>(
                                        showSelectedIcon: false,
                                        style: ButtonStyle(
                                          visualDensity: VisualDensity.compact,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        segments: const [
                                          ButtonSegment<String>(
                                            value: 'zh',
                                            label: Text('中'),
                                          ),
                                          ButtonSegment<String>(
                                            value: 'en',
                                            label: Text('EN'),
                                          ),
                                        ],
                                        selected: {_isZh ? 'zh' : 'en'},
                                        onSelectionChanged: (value) {
                                          final target = value.first;
                                          if ((target == 'zh' && _isZh) ||
                                              (target == 'en' && !_isZh)) {
                                            return;
                                          }
                                          widget.onToggleLocale?.call();
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SegmentedButton<bool>(
                                    showSelectedIcon: false,
                                    segments: [
                                      ButtonSegment<bool>(
                                        value: true,
                                        label: Text(_t('Login', '登录')),
                                      ),
                                      ButtonSegment<bool>(
                                        value: false,
                                        label: Text(_t('Sign Up', '注册')),
                                      ),
                                    ],
                                    selected: {_isLoginMode},
                                    onSelectionChanged: _submitting
                                        ? null
                                        : (v) => setState(() {
                                            _isLoginMode = v.first;
                                            _error = null;
                                          }),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: _t('Email', '邮箱'),
                                      prefixIcon: const Icon(
                                        Icons.alternate_email_rounded,
                                      ),
                                      suffixIcon: _rememberedEmails.isEmpty
                                          ? null
                                          : PopupMenuButton<String>(
                                              tooltip: _t(
                                                'Choose remembered email',
                                                '选择已记忆邮箱',
                                              ),
                                              icon: const Icon(
                                                Icons.arrow_drop_down_rounded,
                                              ),
                                              onSelected: (v) => setState(
                                                () => _emailCtrl.text = v,
                                              ),
                                              itemBuilder: (_) =>
                                                  _rememberedEmails
                                                      .map(
                                                        (e) =>
                                                            PopupMenuItem<
                                                              String
                                                            >(
                                                              value: e,
                                                              child: Text(e),
                                                            ),
                                                      )
                                                      .toList(growable: false),
                                            ),
                                    ),
                                    validator: (v) {
                                      final text = (v ?? '').trim();
                                      if (text.isEmpty) {
                                        return _t(
                                          'Please input email',
                                          '请输入邮箱',
                                        );
                                      }
                                      if (!text.contains('@')) {
                                        return _t(
                                          'Invalid email format',
                                          '邮箱格式不正确',
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _passwordCtrl,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: _t('Password', '密码'),
                                      prefixIcon: const Icon(
                                        Icons.lock_rounded,
                                      ),
                                    ),
                                    validator: (v) {
                                      final text = v ?? '';
                                      if (text.length < 6) {
                                        return _t(
                                          'Password must be at least 6 characters',
                                          '密码至少 6 位',
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                  if (_isLoginMode) ...[
                                    const SizedBox(height: 6),
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: _autoLogin30Days,
                                      onChanged: _submitting
                                          ? null
                                          : (v) => setState(
                                              () =>
                                                  _autoLogin30Days = v ?? false,
                                            ),
                                      title: Text(
                                        _t(
                                          'Auto login for 30 days',
                                          '30天内自动登录',
                                        ),
                                      ),
                                      subtitle: Text(
                                        _t(
                                          'If unchecked, login is required each time app starts.',
                                          '不勾选则每次打开应用都需要重新登录。',
                                        ),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ),
                                  ],
                                  if (!_isLoginMode) ...[
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _confirmPasswordCtrl,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: _t(
                                          'Confirm password',
                                          '确认密码',
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.verified_user_rounded,
                                        ),
                                      ),
                                      validator: (v) {
                                        if ((v ?? '') != _passwordCtrl.text) {
                                          return _t(
                                            'Passwords do not match',
                                            '两次输入密码不一致',
                                          );
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
                                    onPressed: _submitting ? null : _submit,
                                    icon: Icon(
                                      _isLoginMode
                                          ? Icons.login_rounded
                                          : Icons.person_add_alt_1_rounded,
                                    ),
                                    label: Text(
                                      _submitting
                                          ? _t('Processing...', '处理中...')
                                          : (_isLoginMode
                                                ? _t('Login', '登录')
                                                : _t('Create Account', '创建账户')),
                                    ),
                                  ),
                                  if (_isLoginMode) ...[
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _submitting
                                          ? null
                                          : _continueAsGuest,
                                      icon: const Icon(Icons.person_outline),
                                      label: Text(
                                        _t('Continue as Guest', '访客使用'),
                                      ),
                                    ),
                                  ],
                                  if (_isLoginMode) ...[
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _submitting
                                            ? null
                                            : _openOtpResetPage,
                                        child: Text(
                                          _t('Forgot password?', '忘记密码？'),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _t(
                                        'A verification email will be sent. You must verify before login.',
                                        '系统会发送验证邮件，完成邮箱验证后才能登录。',
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
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
      ),
    );
  }
}
