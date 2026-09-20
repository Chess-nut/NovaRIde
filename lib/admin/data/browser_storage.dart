import 'package:novaride/admin/data/browser_storage_stub.dart'
    if (dart.library.js_interop) 'package:novaride/admin/data/browser_storage_web.dart'
    as platform;

/// The last email that signed in, kept in the browser's local storage when
/// the operator asks for it.
///
/// The address only — never the password, never a role. It exists so a
/// returning operator lands on the password field instead of retyping an
/// institutional address, which is the same convenience real operations
/// tools offer and nothing more. Storage is per browser profile: a different
/// machine, or a cleared profile, starts blank.
///
/// On the web this is `window.localStorage`, reached through `dart:js_interop`
/// so the project takes no package for it. Anywhere else — the VM that runs
/// `flutter test` — it is an in-memory map, so the checkbox behaves the same
/// under test and nothing here ever needs mocking.
class RememberedEmail {
  const RememberedEmail._();

  static const _key = 'novaride.console.rememberedEmail';

  /// The saved address, or null when none is saved.
  static String? load() {
    final email = platform.read(_key)?.trim();
    return (email == null || email.isEmpty) ? null : email;
  }

  static void save(String email) => platform.write(_key, email.trim());

  static void clear() => platform.remove(_key);
}
