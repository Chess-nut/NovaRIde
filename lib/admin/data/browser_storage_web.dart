/// `window.localStorage` through `dart:js_interop`, selected by the
/// conditional import in `browser_storage.dart` on web builds.
///
/// Every access is guarded: a browser with storage disabled, or a sandboxed
/// context, throws on the property itself, and a full quota throws on write.
/// None of that is worth failing a sign-in over, so a refused read is a
/// missing value and a refused write is silently dropped.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _storage {
  try {
    return globalContext.getProperty<JSObject?>('localStorage'.toJS);
  } catch (_) {
    // Storage disabled for this origin; behave as if nothing is saved.
    return null;
  }
}

String? read(String key) {
  try {
    return _storage
        ?.callMethod<JSString?>('getItem'.toJS, key.toJS)
        ?.toDart;
  } catch (_) {
    // Unreadable storage is the same as an empty one.
    return null;
  }
}

void write(String key, String value) {
  try {
    _storage?.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
  } catch (_) {
    // Quota exceeded or storage refused: the convenience is lost, not the sign-in.
  }
}

void remove(String key) {
  try {
    _storage?.callMethod<JSAny?>('removeItem'.toJS, key.toJS);
  } catch (_) {
    // Nothing to remove from a storage that cannot be reached.
  }
}
