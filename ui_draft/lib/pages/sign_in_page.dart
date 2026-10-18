import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';

const _errorColor = Color(0xFFB3261E);

/// Minimal email + password screen. A stand-in so the account flow can be
/// tested end to end; replace it when the real login design is ready.
/// Open it with: context.push('/signin')
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false; // false = sign in, true = create account
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_creating) {
        await AuthService.instance.createAccount(_email.text, _password.text);
      } else {
        await AuthService.instance.signIn(_email.text, _password.text);
      }
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go('/create');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFor(e));
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
                Text('An account lets you add events and follow their review.',
                    style: GoogleFonts.outfit(fontSize: 13, height: 1.5, color: AppColors.inkMid)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.ink),
                  decoration: _decoration('Email'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    return (t.contains('@') && t.contains('.')) ? null : 'Enter a valid email';
                  },
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
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: GoogleFonts.outfit(fontSize: 12, color: _errorColor)),
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
                    onTap: () => setState(() { _creating = !_creating; _error = null; }),
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
