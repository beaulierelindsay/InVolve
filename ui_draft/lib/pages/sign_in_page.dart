import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';

const _errorColor = Color(0xFFB3261E);

/// Sign in or create an account (email + password).
/// Open it with: context.push('/signin')
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false; // false = sign in, true = create account
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String v) => v.contains('@') && v.contains('.');

  void _leave() => context.canPop() ? context.pop() : context.go('/create');

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; _info = null; });
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_creating) {
        await AuthService.instance.createAccount(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
        messenger.showSnackBar(const SnackBar(
          content: Text('Account created. Check your email to verify your address.'),
        ));
      } else {
        await AuthService.instance.signIn(_email.text, _password.text);
      }
      if (mounted) _leave();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFor(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() {
        _error = 'Enter your email above, then tap "Forgot password?".';
        _info = null;
      });
      return;
    }
    setState(() { _busy = true; _error = null; _info = null; });
    // Same wording whether or not an account exists, so the screen can't be
    // used to find out which emails are registered.
    final sent = 'If an account exists for $email, a reset link is on its way.';
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) setState(() => _info = sent);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'user-not-found') {
          _info = sent;
        } else {
          _error = AuthService.messageFor(e);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String hint) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.inkMuted),
      filled: true,
      fillColor: AppColors.canvas,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.forest),
      errorBorder: border(_errorColor),
      focusedErrorBorder: border(_errorColor),
      errorStyle: GoogleFonts.outfit(fontSize: 11, color: _errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.canPop() ? context.pop() : context.go('/feed'),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, size: 22, color: AppColors.inkMid),
                        Text('Back', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkMid)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(_creating ? 'CREATE ACCOUNT' : 'WELCOME BACK',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.amber)),
                const SizedBox(height: 6),
                Text(_creating ? 'Join InVolve' : 'Sign in',
                    style: GoogleFonts.fraunces(fontSize: 30, fontWeight: FontWeight.w300, color: AppColors.ink)),
                const SizedBox(height: 8),
                Text('An account lets you add events and see how they\u2019re reviewed.',
                    style: GoogleFonts.outfit(fontSize: 13, height: 1.5, color: AppColors.inkMid)),
                const SizedBox(height: 28),
                if (_creating) ...[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.givenName],
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.ink),
                    decoration: _decoration('First name'),
                    validator: (v) => (v?.trim().length ?? 0) >= 2 ? null : 'Enter your name',
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.ink),
                  decoration: _decoration('Email'),
                  validator: (v) => _looksLikeEmail(v?.trim() ?? '') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.ink),
                  decoration: _decoration('Password'),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => (v ?? '').length >= 6 ? null : 'At least 6 characters',
                ),
                if (!_creating)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _busy ? null : _forgotPassword,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 0, 4),
                        child: Text('Forgot password?',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forest)),
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: GoogleFonts.outfit(fontSize: 12, color: _errorColor)),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  Text(_info!, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.forest, height: 1.4)),
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_creating ? 'Create account' : 'Sign in',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() { _creating = !_creating; _error = null; _info = null; }),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _creating ? 'Already have an account? Sign in' : 'New here? Create an account',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.forest),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
