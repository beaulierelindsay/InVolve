import 'package:firebase_auth/firebase_auth.dart';

/// The one place the app talks to Firebase Auth. If the login method changes
/// (Google, Apple, phone...), only this file and the sign-in screen change.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// True only for a real account. Anonymous sessions don't count, because
  /// they give no accountability for who submitted what.
  bool get isSignedIn {
    final user = currentUser;
    return user != null && !user.isAnonymous;
  }

  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Emits on sign-in, sign-out AND profile changes (like a new display name),
  /// so screens showing the name update without a restart.
  Stream<User?> get changes => _auth.userChanges();

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  /// Creates the account, saves the display name, and sends a verification
  /// email. If the account is created but the name or email step fails, the
  /// account still exists, so those failures are not treated as sign-up errors.
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user;
    if (user == null) return;
    try {
      await user.updateDisplayName(name.trim());
      await user.sendEmailVerification();
      await user.reload();
    } catch (_) {
      // Non-fatal: the user can fix their name later, or request another email.
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// Plain-language message for a Firebase Auth error.
  static String messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address doesn\u2019t look right.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account with that email already exists. Try signing in.';
      case 'weak-password':
        return 'Choose a password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Couldn\u2019t reach the server. Check your connection.';
      case 'operation-not-allowed':
        return 'Email sign-in isn\u2019t turned on yet. Ask the team to enable it in Firebase.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
