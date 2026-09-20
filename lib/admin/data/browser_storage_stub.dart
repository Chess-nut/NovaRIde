/// In-memory stand-in for the browser's local storage, selected by the
/// conditional import in `browser_storage.dart` wherever `dart:js_interop`
/// is unavailable — which is the VM, so every widget test runs against this.
/// Process-wide on purpose: a page that saves and a later page that loads
/// see the same map, exactly as two page loads share `localStorage`.
library;

final _memory = <String, String>{};

String? read(String key) => _memory[key];

void write(String key, String value) => _memory[key] = value;

void remove(String key) => _memory.remove(key);
