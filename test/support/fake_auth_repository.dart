// An AuthRepository that never touches Firebase.
//
// The interface exists so the screens, the router and the gate can be
// tested without a network, an emulator or a project. This is that seam
// being used: every widget test below overrides authRepositoryProvider
// with one of these.
//
// It keeps the parts of the real contract the UI depends on — the auth
// stream, the same Failure types, the same generic sentence for a bad
// credential — and none of the parts it does not.

import 'dart:async';

import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.accounts = const {},
    this.usernames = const {},
    this.failWith,
  });

  /// email -> (password, profile). Username sign-in resolves through
  /// [usernames] first, exactly as the real one resolves through
  /// `usernames/{usernameLower}`.
  final Map<String, (String, UserProfile)> accounts;

  /// usernameLower -> email.
  final Map<String, String> usernames;

  /// When set, every call throws it. For the error paths.
  final Failure? failWith;

  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _current;

  /// Everything the fake was asked to do, in order, for tests that care
  /// that ensureProfile ran or that a verification email was sent.
  final List<String> calls = [];

  void dispose() => _controller.close();

  @override
  UserProfile? get currentUser => _current;

  /// Emits the current session on subscribe, then every change.
  ///
  /// Firebase does this — `userChanges()` hands a new listener the state
  /// it already knows before waiting for the next one — and it matters:
  /// without the first event the app sits on the splash screen forever,
  /// because AuthState starts `unknown` and only a stream event resolves
  /// it.
  @override
  Stream<UserProfile?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  /// Pushes a session onto the stream, the way Firebase would.
  void emit(UserProfile? profile) {
    _current = profile;
    _controller.add(profile);
  }

  Never _fail() => throw failWith!;

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signInWithEmail:$email');
    if (failWith != null) _fail();
    final match = accounts[email.trim().toLowerCase()];
    if (match == null || match.$1 != password) {
      throw const AuthFailure('Incorrect email or password.');
    }
    emit(match.$2);
    return match.$2;
  }

  @override
  Future<UserProfile> signInWithGoogle({required UserRole role}) async {
    calls.add('signInWithGoogle:${role.wireName}');
    if (failWith != null) _fail();
    final profile = UserProfile(
      uid: 'uid-google',
      email: 'google@example.test',
      username: 'google_user',
      fullName: 'Google User',
      role: role,
      emailVerified: true,
    );
    emit(profile);
    return profile;
  }

  @override
  Future<UserProfile> signInWithUsername({
    required String username,
    required String password,
  }) async {
    calls.add('signInWithUsername:$username');
    if (failWith != null) _fail();
    // One sentence for both halves, exactly as the real repository does
    // it: an unknown username and a wrong password must not be
    // distinguishable from the screen. Delegating to signInWithEmail
    // here would be wrong — that path says "Incorrect email or
    // password", a different string, which is the leak.
    const generic = AuthFailure('Incorrect username or password.');
    final email = usernames[username.trim().toLowerCase()];
    if (email == null) throw generic;
    final match = accounts[email.trim().toLowerCase()];
    if (match == null || match.$1 != password) throw generic;
    emit(match.$2);
    return match.$2;
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    calls.add('signUp:$email:$username:${role.wireName}');
    if (failWith != null) _fail();
    if (usernames.containsKey(username.trim().toLowerCase())) {
      throw const ValidationFailure(
        'That username is taken. Try another.',
        field: 'username',
      );
    }
    final profile = UserProfile(
      uid: 'uid-$username',
      email: email.trim(),
      username: username.trim(),
      fullName: fullName.trim(),
      role: role,
      // New accounts are unverified, which is what puts the router on
      // the verify-email screen.
      emailVerified: false,
      phoneNumber: phoneNumber,
    );
    emit(profile);
    return profile;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    calls.add('isUsernameAvailable:$username');
    return !usernames.containsKey(username.trim().toLowerCase());
  }

  @override
  Future<void> sendEmailVerification() async {
    calls.add('sendEmailVerification');
    if (failWith != null) _fail();
  }

  @override
  Future<UserProfile> reloadUser() async {
    calls.add('reloadUser');
    if (failWith != null) _fail();
    final current = _current;
    if (current == null) throw const AuthFailure('You are not signed in.');
    return current;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    calls.add('sendPasswordResetEmail:$email');
    if (failWith != null) _fail();
  }

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? address,
  }) async {
    calls.add(
      'updateProfile:${fullName ?? ''}|${phoneNumber ?? ''}|'
      '${address ?? ''}',
    );
    if (failWith != null) _fail();
    final current = _current;
    if (current == null) throw const AuthFailure('You are not signed in.');
    // The real one cannot move email, username or role, and the rules
    // refuse them; copyWith is not even offered those here.
    final updated = current.copyWith(
      fullName: fullName?.trim(),
      phoneNumber: phoneNumber?.trim(),
      address: address?.trim(),
    );
    emit(updated);
    return updated;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(null);
  }
}
