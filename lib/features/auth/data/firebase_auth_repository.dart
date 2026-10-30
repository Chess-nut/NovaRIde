import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/firebase_failure_mapper.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/entities/user_profile.dart';
import '../domain/entities/user_role.dart';
import '../domain/repositories/auth_repository.dart';

/// [AuthRepository] against Firebase Auth and Cloud Firestore.
///
/// The interface's contract is that every failure leaves here as a
/// [Failure] with a sentence on it — never a `FirebaseException`, never a
/// bare `Exception`. That boundary is kept in exactly one place: the
/// private `_guard` below wraps every public method, so a caller can rely
/// on `catch (e)` giving it something it can put on screen.
///
/// The interesting part is [ensureProfile]. Everything else is a thin
/// wrapper over the SDK.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// The last profile resolved, so [currentUser] can answer without a read.
  UserProfile? _cached;
  String? _cachedUid;

  /// Non-null while [signUp] owns the session.
  ///
  /// `userChanges()` fires the instant `createUserWithEmailAndPassword`
  /// returns — before signUp has written a single document. Without this
  /// gate the stream's own [ensureProfile] runs first, finds no
  /// `users/{uid}` and no role to build one from, throws, and signs the
  /// account out from under the sign-up that is still running.
  ///
  /// That is not theoretical. It produced exactly three symptoms, all of
  /// which were seen: a permission-denied on signUp's write, because by
  /// the time it ran the session was gone and `isOwner()` had no uid to
  /// match; `[firebase_auth/no-current-user]` when signUp then tried to
  /// delete the account it had just created; and an orphaned Auth account
  /// left behind every time.
  ///
  /// The stream waits on this rather than racing it.
  Completer<void>? _signUpGate;

  // ------------------------------------------------------------- session

  @override
  UserProfile? get currentUser =>
      _auth.currentUser?.uid == _cachedUid ? _cached : null;

  /// Firebase's own stream, mapped to profiles.
  ///
  /// `userChanges()` rather than `authStateChanges()`: the latter does not
  /// fire when `reload()` flips `emailVerified`, and the router holds an
  /// unverified account on the verify-email screen. Without this the
  /// screen's "I have confirmed it" button would refresh the token and
  /// nothing would move.
  @override
  Stream<UserProfile?> authStateChanges() =>
      _auth.userChanges().asyncMap(_profileFor);

  Future<UserProfile?> _profileFor(fb.User? user) async {
    if (user == null) {
      _cached = null;
      _cachedUid = null;
      return null;
    }
    // A sign-up in flight owns this uid's documents. Wait for it to
    // finish writing them instead of racing it — see [_signUpGate].
    final gate = _signUpGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }

    // Already resolved this uid, so there is nothing to read: signUp and
    // signIn both call ensureProfile themselves, and this event is the
    // echo of one of them. Only `emailVerified` can have moved, and it
    // comes from Auth rather than from Firestore — which is what makes
    // the verify-email screen work without a round trip.
    if (_cachedUid == user.uid && _cached != null) {
      final refreshed = _cached!.copyWith(emailVerified: user.emailVerified);
      _cached = refreshed;
      return refreshed;
    }

    // A session restored at launch, or one this process did not create.
    // Resolve it the same way a sign-in does, so the app never runs on a
    // uid whose documents it has not seen.
    try {
      final profile = await ensureProfile(user);
      _cached = profile;
      _cachedUid = user.uid;
      return profile;
    } catch (error, stack) {
      // Signed in with no usable profile is a state nothing downstream can
      // handle: the router would have a uid and no role. End the session
      // rather than let the app run in it.
      AppLogger.e('Session for ${user.uid} has no usable profile; signing out.',
          error: error, stackTrace: stack);
      await signOut();
      return null;
    }
  }

  // ------------------------------------------------------------- sign-in

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _finishSignIn(credential.user);
    });
  }

  /// Sign in with a username.
  ///
  /// Two things can go wrong here and they must be indistinguishable: the
  /// username belongs to nobody, or it belongs to someone and the
  /// password is wrong. If those produced different sentences, the screen
  /// would be a way to find out which usernames are registered — which is
  /// the same reason a wrong password and an unknown email share a
  /// sentence in the failure mapper.
  ///
  /// Getting this right takes more than throwing one string in the
  /// not-found branch: the other branch goes through Firebase, whose
  /// `invalid-credential` maps to "Incorrect email or password" — a
  /// *different* sentence, and one that says "email" to somebody who
  /// typed a username. So every credential-shaped refusal is folded into
  /// the one message below.
  ///
  /// `user-disabled` is deliberately left alone. It does reveal that an
  /// account exists, and it is worth it: "this account has been turned
  /// off" is something the person can act on, and an attacker learns only
  /// about accounts already switched off.
  @override
  Future<UserProfile> signInWithUsername({
    required String username,
    required String password,
  }) {
    return _guard(() async {
      const generic = AuthFailure('Incorrect username or password.');

      final email = await _emailForUsername(username);
      if (email == null) throw generic;

      final fb.UserCredential credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on fb.FirebaseAuthException catch (error) {
        if (_credentialCodes.contains(error.code)) throw generic;
        rethrow;
      }
      return _finishSignIn(credential.user);
    });
  }

  /// Every code that means "those details did not work", across the
  /// spellings Firebase has used. They all collapse to one sentence.
  static const _credentialCodes = {
    'wrong-password',
    'user-not-found',
    'invalid-credential',
    'invalid-login-credentials',
    'INVALID_LOGIN_CREDENTIALS',
    'invalid-email',
    'missing-password',
  };

  /// Resolves a username to the address Firebase Auth will accept.
  ///
  /// `usernames/{usernameLower}` is the one document an unauthenticated
  /// client may read — see the note above that rule in firestore.rules.
  Future<String?> _emailForUsername(String username) async {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) return null;
    final snapshot =
        await _firestore.collection(FirestoreCollections.usernames).doc(key).get();
    if (!snapshot.exists) return null;
    final email = snapshot.data()?['email'];
    return email is String && email.isNotEmpty ? email : null;
  }

  @override
  Future<bool> isUsernameAvailable(String username) {
    return _guard(() async {
      final key = username.trim().toLowerCase();
      if (key.isEmpty) return false;
      final snapshot = await _firestore
          .collection(FirestoreCollections.usernames)
          .doc(key)
          .get();
      return !snapshot.exists;
    });
  }

  // ------------------------------------------------------------- sign-up

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required UserRole role,
    String? phoneNumber,
  }) {
    return _guard(() async {
      // Held for the whole of sign-up, and released in the finally
      // below whatever happens. The auth stream waits on it rather than
      // provisioning the half-made account itself.
      final gate = Completer<void>();
      _signUpGate = gate;
      try {
        return await _signUp(
          email: email,
          password: password,
          username: username,
          fullName: fullName,
          role: role,
          phoneNumber: phoneNumber,
        );
      } finally {
        _signUpGate = null;
        if (!gate.isCompleted) gate.complete();
      }
    });
  }

  Future<UserProfile> _signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    {
      final key = username.trim().toLowerCase();

      // A pre-check, so the common case fails before an Auth account is
      // created and has to be cleaned up. It is not the guarantee — the
      // transaction below re-reads inside its own read set, which is what
      // actually makes the claim atomic. Anything checked before a write
      // can be taken between the two.
      if (!await isUsernameAvailable(key)) {
        throw const ValidationFailure(
          'That username is taken. Try another.',
          field: 'username',
        );
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          'The account was not created. Try again.',
        );
      }

      try {
        final profile = await ensureProfile(
          user,
          username: username.trim(),
          fullName: fullName.trim(),
          role: role,
          phoneNumber: phoneNumber?.trim(),
        );
        await user.sendEmailVerification();
        _cached = profile;
        _cachedUid = user.uid;
        return profile;
      } catch (error, stack) {
        // The Auth account exists and its documents do not. Signing out
        // is not enough: it leaves an account behind that can never be
        // used, because signing into it finds no users/ document and
        // fails the same way. Two of those were created for real before
        // this branch deleted anything.
        //
        // So the account goes too. It was created seconds ago by this
        // same call, which is what makes `delete()` legal without a
        // re-authentication, and nothing else can have started depending
        // on it yet. The person retries and gets a clean attempt rather
        // than "that email is already in use" on an account they cannot
        // reach.
        AppLogger.e('Sign-up for ${user.uid} failed after the Auth account '
            'was created; removing it.', error: error, stackTrace: stack);
        try {
          await user.delete();
        } catch (deleteError, deleteStack) {
          // Out of options: the account is orphaned and only an operator
          // with the Admin SDK can clear it. Say so loudly rather than
          // swallowing it — this is the line that explains a mystery
          // account in the console later.
          AppLogger.e(
            'Could not remove the orphaned Auth account ${user.uid}. It has '
            'no profile documents and cannot be signed into; delete it in '
            'the Firebase console.',
            error: deleteError,
            stackTrace: deleteStack,
          );
          await signOut();
        }
        rethrow;
      }
    }
  }

  // ------------------------------------------------------- verification

  @override
  Future<void> sendEmailVerification() {
    return _guard(() async {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthFailure('You are not signed in.');
      }
      await user.sendEmailVerification();
    });
  }

  @override
  Future<UserProfile> reloadUser() {
    return _guard(() async {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthFailure('You are not signed in.');
      }
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null) {
        throw const AuthFailure('You are not signed in.');
      }
      final profile = await ensureProfile(refreshed);
      _cached = profile;
      _cachedUid = refreshed.uid;
      return profile;
    });
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _guard(() async {
      try {
        await _auth.sendPasswordResetEmail(email: email.trim());
      } on fb.FirebaseAuthException catch (error) {
        // An address with no account must look exactly like one that has
        // it: completing either way is what stops this being a way to
        // find out who is registered. Everything else still fails.
        if (error.code == 'user-not-found') return;
        rethrow;
      }
    });
  }

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? address,
  }) {
    return _guard(() async {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthFailure('You are not signed in.');
      }

      // Only the three the rules allow to move, and only the ones the
      // caller actually passed. updatedAt is not optional: every write
      // to users/ has to stamp the server clock or the rules refuse it.
      final edit = <String, Object?>{
        if (fullName != null) 'fullName': fullName.trim(),
        if (phoneNumber != null) 'phoneNumber': phoneNumber.trim(),
        if (address != null) 'address': address.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final ref =
          _firestore.collection(FirestoreCollections.users).doc(user.uid);
      await ref.update(edit);

      // Re-read rather than patch the cache: the document is the truth,
      // and the server timestamp is only resolved once it lands.
      final snapshot = await ref.get();
      final profile = _profileFromDocument(snapshot.data()!, user);
      _cached = profile;
      _cachedUid = user.uid;
      return profile;
    });
  }

  @override
  Future<void> signOut() async {
    _cached = null;
    _cachedUid = null;
    await _auth.signOut();
  }

  Future<UserProfile> _finishSignIn(fb.User? user) async {
    if (user == null) {
      // The SDK contract says this cannot happen for a successful
      // email/password sign-in; treat it as a failed one rather than
      // reason about a session with no user.
      throw const AuthFailure('Sign-in did not complete. Try again.');
    }
    try {
      final profile = await ensureProfile(user);
      _cached = profile;
      _cachedUid = user.uid;
      return profile;
    } catch (error, stack) {
      AppLogger.e('ensureProfile failed for ${user.uid}; signing out.',
          error: error, stackTrace: stack);
      await signOut();
      rethrow;
    }
  }

  // -------------------------------------------------------- the profile

  /// Brings an account's documents up to date, in one transaction, and
  /// returns what they say.
  ///
  /// Called after **every** sign-up and **every** sign-in, and again
  /// whenever the auth stream produces a user. It has to be idempotent,
  /// because most of the time it runs there is nothing to do.
  ///
  /// When the documents are absent it creates them:
  /// `users/{uid}`, the matching `riderProfiles/{uid}` or
  /// `guardianProfiles/{uid}`, and — on sign-up only — the
  /// `usernames/{usernameLower}` claim, all keyed by the Auth uid.
  ///
  /// When they are present it touches `lastLoginAt`, `fcmToken` and
  /// `updatedAt` and nothing else. It never rewrites `role` or
  /// `createdAt`: the role decides which home screen the account gets and
  /// createdAt is evidence for the study. The security rules refuse those
  /// two changes as well, so this is belt and braces on purpose — a bug
  /// here is caught by the server rather than silently rewriting history.
  ///
  /// Every timestamp is [FieldValue.serverTimestamp]. No client clock
  /// reaches Firestore; the rules require `request.time` and would refuse
  /// a `DateTime.now()` anyway.
  ///
  /// [username], [fullName] and [role] are supplied on sign-up, where
  /// there is nothing to read them from yet. On sign-in they are absent
  /// and the existing document is the source of truth.
  Future<UserProfile> ensureProfile(
    fb.User user, {
    String? username,
    String? fullName,
    UserRole? role,
    String? phoneNumber,
    String? fcmToken,
  }) {
    return _withRetry(() => _firestore.runTransaction((transaction) async {
          final userRef = _firestore
              .collection(FirestoreCollections.users)
              .doc(user.uid);
          final existing = await transaction.get(userRef);

          if (existing.exists) {
            return _touchExisting(transaction, userRef, existing, user,
                fcmToken: fcmToken);
          }
          return _createAll(transaction, userRef, user,
              username: username,
              fullName: fullName,
              role: role,
              phoneNumber: phoneNumber,
              fcmToken: fcmToken);
        }));
  }

  /// The already-provisioned path, which is almost every call.
  Future<UserProfile> _touchExisting(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> userRef,
    DocumentSnapshot<Map<String, dynamic>> existing,
    fb.User user, {
    String? fcmToken,
  }) async {
    // Built by the same function the contract test checks against the
    // rules. `role` and `createdAt` are not in it and must never be.
    transaction.update(
      userRef,
      buildLoginTouch(
        serverTimestamp: FieldValue.serverTimestamp(),
        fcmToken: fcmToken,
      ),
    );

    // Read from what was already there, not from what was just written:
    // the server timestamps are unresolved until the transaction commits,
    // and none of the three is a field the app displays anyway.
    return _profileFromDocument(existing.data()!, user);
  }

  /// First sign-in for this uid — either a fresh sign-up, or an Auth
  /// account whose documents never landed because an earlier attempt
  /// failed between the two.
  Future<UserProfile> _createAll(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> userRef,
    fb.User user, {
    String? username,
    String? fullName,
    UserRole? role,
    String? phoneNumber,
    String? fcmToken,
  }) async {
    final resolvedRole = role;
    final resolvedUsername = (username ?? '').trim();
    if (resolvedRole == null || resolvedUsername.isEmpty) {
      // Signed in against an Auth account with no users/ document and no
      // sign-up details to rebuild one from. Guessing a role would hand
      // someone the wrong home screen, so this fails and the caller signs
      // the session out.
      throw const NotFoundFailure(
        'This account is not set up yet. Sign up again, or ask for help if '
        'it keeps happening.',
      );
    }

    final email = user.email ?? '';
    final usernameKey = resolvedUsername.toLowerCase();
    final profileCollection = resolvedRole == UserRole.rider
        ? FirestoreCollections.riderProfiles
        : FirestoreCollections.guardianProfiles;

    // The claim is read inside the transaction, so it is part of the read
    // set: if anyone takes the username between the pre-check and the
    // commit, this transaction is retried or aborted rather than
    // overwriting them. The rules also refuse a write over an existing
    // claim, which is the second line of defence.
    final usernameRef = _firestore
        .collection(FirestoreCollections.usernames)
        .doc(usernameKey);
    final claim = await transaction.get(usernameRef);
    if (claim.exists && claim.data()?['uid'] != user.uid) {
      throw const ValidationFailure(
        'That username is taken. Try another.',
        field: 'username',
      );
    }

    // All three payloads come from the builders below, which is what the
    // contract test runs against the real ruleset. Nothing here writes a
    // password, a hash or a token of any kind; the rules refuse those
    // field names outright on all four paths.
    final userDoc = buildUserDocument(
      email: email,
      username: resolvedUsername,
      fullName: (fullName ?? '').trim(),
      role: resolvedRole,
      phoneNumber: phoneNumber,
      fcmToken: fcmToken,
      serverTimestamp: FieldValue.serverTimestamp(),
    );
    final profileDoc =
        buildProfileDocument(serverTimestamp: FieldValue.serverTimestamp());
    final claimDoc = buildUsernameClaim(
      uid: user.uid,
      email: email,
      serverTimestamp: FieldValue.serverTimestamp(),
    );

    // Dumped before the writes, so the trace survives a refusal — a
    // rejected transaction is exactly when it is wanted.
    await _traceCreate(user, email, profileCollection, usernameKey, userDoc,
        profileDoc, claimDoc);

    transaction.set(userRef, userDoc);
    transaction.set(
      _firestore.collection(profileCollection).doc(user.uid),
      profileDoc,
    );
    if (!claim.exists) {
      transaction.set(usernameRef, claimDoc);
    }

    return UserProfile(
      uid: user.uid,
      email: email,
      username: resolvedUsername,
      fullName: (fullName ?? '').trim(),
      role: resolvedRole,
      emailVerified: user.emailVerified,
      phoneNumber: phoneNumber,
    );
  }

  /// The document plus the two things only Firebase Auth knows.
  UserProfile _profileFromDocument(Map<String, dynamic> data, fb.User user) {
    final profile = UserProfile.fromMap(user.uid, data);
    return profile.copyWith(
      // Auth owns these; the document's copies, if any, are stale.
      emailVerified: user.emailVerified,
      email: user.email ?? profile.email,
    );
  }


  // ---------------------------------------------- the payloads, exactly
  //
  // The four maps ensureProfile writes, pulled out as pure functions so a
  // test can take the *real* payload and run it against the *real*
  // security rules. A shape the rules refuse then fails in the test suite
  // instead of at sign-up.
  //
  // [serverTimestamp] is injected rather than called here so the payloads
  // can be built outside a Firebase app. Production passes
  // `FieldValue.serverTimestamp()`; the contract test passes a marker it
  // can serialise and the Node side turns back into a server timestamp.
  // Nothing else about the maps differs between the two.

  /// `users/{uid}` on first sign-up.
  ///
  /// `fullName` is unconditional: the rules require it to be a string,
  /// and a guardian seeing a username instead of a name during an SOS is
  /// the reason the field exists at all.
  @visibleForTesting
  static Map<String, Object?> buildUserDocument({
    required String email,
    required String username,
    required String fullName,
    required UserRole role,
    required Object serverTimestamp,
    String? phoneNumber,
    String? fcmToken,
  }) {
    return {
      'email': email,
      'username': username,
      'fullName': fullName,
      'role': role.wireName,
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phoneNumber': phoneNumber.trim(),
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      'createdAt': serverTimestamp,
      'updatedAt': serverTimestamp,
      'lastLoginAt': serverTimestamp,
    };
  }

  /// `riderProfiles/{uid}` or `guardianProfiles/{uid}` on first sign-up.
  /// Role-specific fields arrive with the phase that needs them.
  @visibleForTesting
  static Map<String, Object?> buildProfileDocument({
    required Object serverTimestamp,
  }) {
    return {
      'createdAt': serverTimestamp,
      'updatedAt': serverTimestamp,
    };
  }

  /// `usernames/{usernameLower}`. Exactly three fields — the rules use
  /// `hasOnly`, because this document is world-readable.
  @visibleForTesting
  static Map<String, Object?> buildUsernameClaim({
    required String uid,
    required String email,
    required Object serverTimestamp,
  }) {
    return {
      'uid': uid,
      'email': email,
      'createdAt': serverTimestamp,
    };
  }

  /// The update on every later sign-in. Three keys and no others: `role`
  /// and `createdAt` are absent here and must stay absent.
  @visibleForTesting
  static Map<String, Object?> buildLoginTouch({
    required Object serverTimestamp,
    String? fcmToken,
  }) {
    return {
      'lastLoginAt': serverTimestamp,
      'updatedAt': serverTimestamp,
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
    };
  }


  // ------------------------------------------------------------- tracing

  /// Whether to dump every payload before writing it.
  ///
  /// On in debug builds, off in release — the dump contains a uid and an
  /// email address and has no business in a shipped log. Force it either
  /// way with `--dart-define=NOVARIDE_AUTH_TRACE=true|false`.
  static const bool traceWrites =
      bool.fromEnvironment('NOVARIDE_AUTH_TRACE', defaultValue: kDebugMode);

  /// Prints exactly what is about to be written, before it is written.
  ///
  /// Every key, its value and its runtime type, for each document in the
  /// transaction, plus the three identities the rules compare: the uid on
  /// the document path, the email the code read off the Firebase user,
  /// and the email claim actually on the ID token — which is what
  /// `request.auth.token.email` resolves to, and the one value that
  /// cannot be reproduced in the emulator, because there the harness
  /// sets it by hand.
  ///
  /// Written to be pasted into the Rules Playground rather than skimmed.
  Future<void> _traceCreate(
    fb.User user,
    String email,
    String profileCollection,
    String usernameKey,
    Map<String, Object?> userDoc,
    Map<String, Object?> profileDoc,
    Map<String, Object?> claimDoc,
  ) async {
    if (!traceWrites) return;

    // The claims are the point of this whole dump. Reading them is a
    // local decode of the cached token, not a network call.
    String tokenEmail = '<unavailable>';
    String claimKeys = '<unavailable>';
    try {
      final token = await user.getIdTokenResult();
      tokenEmail = '${token.claims?['email']}';
      final keys = token.claims?.keys.toList() ?? <String>[];
      keys.sort();
      claimKeys = keys.join(', ');
    } catch (error) {
      tokenEmail = '<failed: $error>';
    }

    final buffer = StringBuffer()
      ..writeln('=== ensureProfile: CREATE ===')
      ..writeln('uid (document id)      : ${user.uid}')
      ..writeln('user.email             : ${user.email}')
      ..writeln('token email claim      : $tokenEmail')
      ..writeln('email written to docs  : $email')
      ..writeln('emails match (lowered) : '
          '${email.toLowerCase() == tokenEmail.toLowerCase()}')
      ..writeln('token claim keys       : $claimKeys')
      ..writeln('user.isAnonymous       : ${user.isAnonymous}')
      ..writeln('user.emailVerified     : ${user.emailVerified}')
      ..writeln()
      ..write(_describe('users/${user.uid}', userDoc))
      ..write(_describe('$profileCollection/${user.uid}', profileDoc))
      ..write(_describe('usernames/$usernameKey', claimDoc))
      ..writeln('--- paste into the Rules Playground ---')
      ..writeln(_playgroundJson(userDoc))
      ..writeln('=== end ===');

    // One line per line, so the log box does not rewrap the JSON.
    for (final line in buffer.toString().split('\n')) {
      // ignore: avoid_print
      print('[auth-trace] $line');
    }
  }

  /// Each key with its value and its Dart runtime type.
  ///
  /// The type is the interesting column: a rule that asks `is string`
  /// fails on a null, and a null and a missing key are different things
  /// to `.get(field, default)`.
  static String _describe(String path, Map<String, Object?> data) {
    final buffer = StringBuffer('--- $path (${data.length} keys) ---\n');
    for (final key in data.keys.toList()..sort()) {
      final value = data[key];
      final rendered = value is FieldValue
          ? 'FieldValue.serverTimestamp()'
          : '$value';
      buffer.writeln('  $key = $rendered   [${value.runtimeType}]');
    }
    return '$buffer\n';
  }

  /// The document as the Playground wants it, with the sentinels named
  /// rather than printed as an opaque object.
  static String _playgroundJson(Map<String, Object?> data) {
    final entries = data.entries.map((e) {
      final value = e.value;
      if (value is FieldValue) {
        return '  "${e.key}": "<<SERVER TIMESTAMP — tick the clock icon>>"';
      }
      if (value is String) return '  "${e.key}": "$value"';
      return '  "${e.key}": $value';
    });
    return '{\n${entries.join(',\n')}\n}';
  }

  // ------------------------------------------------------------ plumbing

  /// The interface's error contract, kept in one place.
  ///
  /// Everything public goes through here, so no caller ever receives a
  /// `FirebaseException`. A [Failure] passes through untouched — an inner
  /// layer that already mapped its own error keeps its sentence.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Failure {
      rethrow;
    } catch (error, stack) {
      AppLogger.w('Auth call failed', error: error, stackTrace: stack);
      throw failureFrom(error, stack);
    }
  }

  /// One retry, for the two codes that mean "the server was busy".
  ///
  /// `unavailable` and `deadline-exceeded` are transient by definition:
  /// the request never reached a decision, so repeating it is safe.
  /// Nothing else is retried — repeating a `permission-denied` or an
  /// `already-exists` just fails twice and doubles the wait.
  ///
  /// Safe to retry an `ensureProfile` transaction specifically because it
  /// is idempotent: the second attempt re-reads and finds either nothing
  /// (and creates) or the documents the first attempt wrote (and only
  /// touches them).
  Future<T> _withRetry<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable' && error.code != 'deadline-exceeded') {
        rethrow;
      }
      AppLogger.w('Firestore said ${error.code}; retrying once.');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return body();
    }
  }
}
