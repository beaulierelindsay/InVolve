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

  /// Emits whenever someone signs in or out.
  Stream<User?> get changes => _auth.authStateChanges();

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> createAccount(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);

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
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
