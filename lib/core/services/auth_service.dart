import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper over FirebaseAuth for the three sign-in methods the app
/// supports: Email/Password, Google, and Phone (OTP). Translates raw
/// FirebaseAuthExceptions into friendly messages the UI can show directly.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  /// Android (type 1) OAuth client from google-services.json.
  /// Required by Credential Manager to identify the app.
  static const String _googleAndroidClientId =
      '191591955909-q0uvbmfp022b47bbreo7ecleve9gj8l0.apps.googleusercontent.com';

  /// Web (type 3) OAuth client from google-services.json. Passed as
  /// serverClientId so Google returns an ID token Firebase can consume.
  static const String _googleServerClientId =
      '191591955909-gl7100sk2f2nd2cg0t5gldi97lobo9rf.apps.googleusercontent.com';

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // --- Email / password -------------------------------------------------------

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_emailMessage(e));
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_emailMessage(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_emailMessage(e));
    }
  }

  // --- Google -----------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    try {
      if (!_googleInitialized) {
        // Both clientId (Android OAuth) and serverClientId (Web OAuth)
        // are required.  clientId lets Credential Manager resolve the
        // app identity; serverClientId tells Google which audience the
        // ID token should target so Firebase can consume it.
        await GoogleSignIn.instance.initialize(
          clientId: _googleAndroidClientId,
          serverClientId: _googleServerClientId,
        );
        _googleInitialized = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(
          'Google sign-in succeeded but no ID token was returned. '
          'Ensure the Google provider is enabled in Firebase Console '
          'and the OAuth consent screen is published.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException.cancelled();
      }
      throw AuthException(
        'Google sign-in failed: ${e.description ?? e.code.name}',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Google sign-in failed.');
    } catch (e) {
      throw AuthException('Google sign-in failed: $e');
    }
  }

  // --- Phone (OTP) ------------------------------------------------------------

  /// Starts phone verification. On Android auto-retrieval, [onAutoVerified]
  /// may fire without the user typing a code. Otherwise [onCodeSent] gives
  /// back a verificationId to pair with the typed OTP in [confirmOtp].
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
          onAutoVerified();
        } catch (_) {
          onError('Automatic verification failed. Enter the code instead.');
        }
      },
      verificationFailed: (e) => onError(
        e.code == 'invalid-phone-number'
            ? 'That phone number looks invalid. Include the country code.'
            : (e.message ?? 'Phone verification failed.'),
      ),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> confirmOtp(String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        e.code == 'invalid-verification-code'
            ? 'That code isn\'t right. Check and try again.'
            : (e.message ?? 'Could not verify the code.'),
      );
    }
  }

  // --- Sign out ---------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google — ignore.
    }
    await _auth.signOut();
  }

  static String _emailMessage(FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => 'That email address looks invalid.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Wrong email or password.',
    'email-already-in-use' => 'An account already exists for that email.',
    'weak-password' => 'Use a stronger password (at least 6 characters).',
    'network-request-failed' => 'No connection. Check your network.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    _ => e.message ?? 'Something went wrong. Please try again.',
  };
}

class AuthException implements Exception {
  final String message;
  final bool cancelled;
  const AuthException(this.message) : cancelled = false;
  const AuthException.cancelled()
    : message = 'Cancelled',
      cancelled = true;

  @override
  String toString() => message;
}
