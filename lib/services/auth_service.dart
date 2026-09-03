import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thin wrapper over Firebase Auth + Google / Apple Sign-In. Single instance
/// shared across the app. UI widgets stream off [authStateChanges] for routing.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final displayName = name.trim();
    if (displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
      await cred.user?.reload();
    }
    return cred;
  }

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    // On some devices (no Google Play, stale Play Services, offline) the
    // tokens come back null even though signIn() "succeeded" — passing nulls
    // to the credential crashes the native layer, so fail cleanly instead.
    if (googleAuth.idToken == null && googleAuth.accessToken == null) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Google sign-in could not complete. Check your connection '
            'and that Google Play services are available.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// True on the platforms where the native "Sign in with Apple" sheet exists
  /// (iOS 13+, macOS 10.15+). Android/web would need a server-hosted web flow,
  /// which isn't configured — the UI hides the button there instead of
  /// offering a control that always fails.
  bool get isAppleSignInSupported {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  /// Sign in / sign up with Apple. Firebase treats both identically: the first
  /// authorization creates the user, later ones return the same account.
  ///
  /// Returns `null` if the user dismissed the Apple sheet.
  Future<UserCredential?> signInWithApple() async {
    // Apple signs the SHA-256 of the nonce into `identityToken`; Firebase
    // re-hashes the raw nonce we hand it and compares. Ties this credential to
    // this one sign-in attempt so a captured token can't be replayed.
    final rawNonce = generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // Apple reports a plain "canceled" both for a real user dismiss AND
        // when the bundle ID isn't a registered Sign in with Apple client
        // (AKAuthenticationError -7003) — the two are indistinguishable here.
        // Staying silent is right for a real cancel, so log the ambiguity for
        // whoever is debugging a sheet that closes itself immediately.
        debugPrint('Apple sign-in reported cancel. If the sheet closed on its '
            'own, check that Sign In with Apple is enabled for this App ID; '
            'look for AKAuthenticationError -7003 in the device log.');
        return null;
      }
      rethrow;
    }

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'apple-missing-identity-token',
        message: 'Apple did not return an identity token. Check that Sign In '
            'with Apple is enabled for this App ID, then try again.',
      );
    }

    // Must be AppleAuthProvider, not OAuthProvider. OAuthProvider.credential()
    // tags the credential `signInMethod: 'oauth'`, which the iOS plugin
    // dispatches to the generic FIROAuthProvider
    // credentialWithProviderID:IDToken:rawNonce:accessToken: — and Firebase
    // rejects Apple tokens sent down that path with `invalid-credential`
    // ("Invalid OAuth response from apple.com") even though the token itself
    // is valid. AppleAuthProvider tags it 'apple.com', reaching
    // appleCredentialWithIDToken:rawNonce:fullName:, which is what Apple
    // sign-in requires. Note the authorizationCode is still deliberately not
    // sent: it's a one-time OAuth *authorization code*, not an access token.
    //
    // Handing the name over here also lets Firebase persist it during the
    // first authorization — the only time Apple ever sends it.
    final oauthCredential = AppleAuthProvider.credentialWithIDToken(
      idToken,
      rawNonce,
      AppleFullPersonName(
        givenName: appleCredential.givenName,
        familyName: appleCredential.familyName,
      ),
    );
    final UserCredential cred;
    try {
      cred = await _auth.signInWithCredential(oauthCredential);
    } on FirebaseAuthException catch (e) {
      // Firebase reuses `invalid-credential` for both a mistyped password and
      // an Apple token it refused. The usual cause here is the Apple provider
      // not being configured in the Firebase console (Services ID / Team ID /
      // Key ID / private key). Log the raw code so it survives the mapping to
      // a user-facing string.
      debugPrint('Apple credential rejected by Firebase: '
          '${e.code} — ${e.message}');
      rethrow;
    }

    // Apple only hands over the name on the *first* authorization for this
    // app; every later sign-in returns nulls. Persist it onto the Firebase
    // profile now or it's gone for good.
    final fullName = [
      appleCredential.givenName ?? '',
      appleCredential.familyName ?? '',
    ].where((p) => p.isNotEmpty).join(' ').trim();
    final existingName = cred.user?.displayName?.trim() ?? '';
    if (fullName.isNotEmpty && existingName.isEmpty) {
      await cred.user?.updateDisplayName(fullName);
      await cred.user?.reload();
    }
    return cred;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Provider ids backing the current account ('password', 'google.com',
  /// 'apple.com'). Empty when signed out.
  Set<String> get providerIds =>
      currentUser?.providerData.map((p) => p.providerId).toSet() ??
      const <String>{};

  /// True when deleting the account needs a password typed in. Federated
  /// accounts re-authorize through their own sheet instead, so the UI only
  /// asks for a password when this is set.
  bool get deletionNeedsPassword {
    final ids = providerIds;
    return !ids.contains('apple.com') && !ids.contains('google.com');
  }

  /// Permanently delete the signed-in account.
  ///
  /// Firebase refuses `delete()` on a stale credential
  /// (`requires-recent-login`), so this re-authenticates first, through the
  /// provider the account was created with. [password] is required for
  /// email/password accounts and ignored for federated ones.
  ///
  /// Throws [FirebaseAuthException] on failure; run it through
  /// [describeError] for display. Local app data is deliberately NOT touched
  /// here — the caller wipes it, so this stays a pure auth concern.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in account to delete.',
      );
    }

    final ids = providerIds;
    // Apple hands back a fresh authorization code during re-auth; it is the
    // only thing that can revoke the Sign in with Apple grant, and it is
    // short-lived, so capture it here and spend it below.
    String? appleAuthorizationCode;

    if (ids.contains('apple.com')) {
      appleAuthorizationCode = await _reauthenticateWithApple(user);
    } else if (ids.contains('google.com')) {
      await _reauthenticateWithGoogle(user);
    } else {
      if (password == null || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-password',
          message: 'Enter your password to confirm account deletion.',
        );
      }
      final email = user.email;
      if (email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: 'no-email-on-account',
          message: 'This account has no email address to re-authenticate with.',
        );
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    }

    // App Store Review Guideline 5.1.1(v): an app offering Sign in with Apple
    // must revoke the Apple grant on account deletion, not merely drop the
    // Firebase user. Has to happen while the user still exists.
    if (appleAuthorizationCode != null && appleAuthorizationCode.isNotEmpty) {
      try {
        await _auth.revokeTokenWithAuthorizationCode(appleAuthorizationCode);
      } on FirebaseAuthException catch (e) {
        // A failed revoke must not strand the user with an account they asked
        // to delete — press on and delete, but leave a trail, since Apple can
        // reject a build whose revoke silently never happens.
        debugPrint('Apple token revoke failed: ${e.code} — ${e.message}');
      }
    }

    await user.delete();
    // The Google plugin caches the chosen account independently of Firebase;
    // without this the next sign-in silently reuses the deleted identity.
    await _googleSignIn.signOut();
  }

  /// Re-authorize through the Apple sheet. Returns the authorization code the
  /// token revoke needs.
  Future<String?> _reauthenticateWithApple(User user) async {
    final rawNonce = generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        // Name and email are already on the account; re-auth only needs to
        // prove the Apple ID still belongs to whoever is holding the phone.
        scopes: const [],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw FirebaseAuthException(
          code: 'reauth-cancelled',
          message: 'Account deletion cancelled.',
        );
      }
      rethrow;
    }

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'apple-missing-identity-token',
        message: 'Apple did not return an identity token. Try again.',
      );
    }

    // Same AppleAuthProvider requirement as sign-in — see signInWithApple.
    await user.reauthenticateWithCredential(
      AppleAuthProvider.credentialWithIDToken(
        idToken,
        rawNonce,
        AppleFullPersonName(),
      ),
    );
    return appleCredential.authorizationCode;
  }

  Future<void> _reauthenticateWithGoogle(User user) async {
    // Sign out of the plugin first so the account chooser actually appears;
    // otherwise it silently reuses the cached account and the user never gets
    // to confirm which identity they are about to destroy.
    await _googleSignIn.signOut();
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'reauth-cancelled',
        message: 'Account deletion cancelled.',
      );
    }
    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null && googleAuth.accessToken == null) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Google sign-in could not complete. Check your connection.',
      );
    }
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );
  }

  /// Map a thrown Firebase / Google / Apple error to a user-readable string.
  ///
  /// Pass [provider] ('Apple', 'Google') from the federated buttons. Firebase
  /// reports a rejected OAuth token with the same `invalid-credential` code it
  /// uses for a wrong password, so without it those failures surface as
  /// "Wrong email or password." on a button that never asked for either.
  static String describeError(Object e, {String? provider}) {
    if (e is SignInWithAppleNotSupportedException) {
      return 'Sign in with Apple needs iOS 13 or later.';
    }
    if (e is SignInWithAppleAuthorizationException) {
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          return 'Apple sign-in cancelled.';
        case AuthorizationErrorCode.notInteractive:
        case AuthorizationErrorCode.notHandled:
          return 'Apple sign-in could not be completed. Try again.';
        case AuthorizationErrorCode.invalidResponse:
        case AuthorizationErrorCode.failed:
        case AuthorizationErrorCode.unknown:
          return 'Apple sign-in failed. Make sure you are signed in to '
              'iCloud in Settings, then try again.';
        case AuthorizationErrorCode.credentialExport:
        case AuthorizationErrorCode.credentialImport:
        case AuthorizationErrorCode.matchedExcludedCredential:
          return 'Apple sign-in failed. Try again.';
      }
    }
    if (e is SignInWithAppleException) {
      return 'Apple sign-in failed. Try again.';
    }
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'account-exists-with-different-credential':
          return 'An account with that email already exists — sign in with '
              'the method you used originally.';
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
          return 'No account found with that email.';
        case 'wrong-password':
          return 'Wrong email or password.';
        case 'invalid-credential':
          if (provider != null) {
            return '$provider sign-in was rejected. Check that $provider is '
                'enabled and configured as a sign-in provider in Firebase.';
          }
          return 'Wrong email or password.';
        case 'email-already-in-use':
          return 'An account with that email already exists.';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters.';
        case 'operation-not-allowed':
          return 'This sign-in method is disabled in Firebase.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a moment and try again.';
        case 'requires-recent-login':
          return 'For your security, sign in again before deleting your '
              'account.';
        case 'missing-password':
        case 'no-email-on-account':
        case 'no-current-user':
          return e.message ?? 'Account deletion failed (${e.code}).';
        case 'reauth-cancelled':
          return 'Account deletion cancelled.';
        default:
          return e.message ?? 'Sign-in failed (${e.code}).';
      }
    }
    return e.toString();
  }
}
