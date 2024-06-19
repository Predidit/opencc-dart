import 'dart:ffi' as ffi;
import 'dart:convert' show utf8;

import 'package:ffi/ffi.dart' show Utf8, Utf8Pointer, calloc;

CharArray _fillChars(String str, CharArray Function(int size) getter) {
  final units = utf8.encode(str);
  final size = units.length + 1;
  final len = size - 1;
  final buf = getter(size);
  final pointer = buf._buf.cast<ffi.Uint8>();
  final raw = pointer.asTypedList(size);
  raw.setAll(0, units);
  raw[len] = 0;
  buf._len = len;
  return buf;
}

/// Util class for data conversion between Dart `String` and C `const char *`.
/// From Dart `String` to C `const char *`:
/// ```dart
/// final cStr = CharArray.from('some thing as string');
/// final p = cStr.pointer;
/// call_some_C_function(p, cStr.length);
/// cStr.dispose();
/// ```
/// To reuse an existing `CharArray`:
/// ```dart
/// CharArray cStr;
/// final p = cStr.pavedBy('some thing as string');
/// call_some_C_function(p, cStr.length);
/// cStr.dispose();
/// ```
///
/// From C `const char *` to Dart `String`:
/// ```dart
/// final p = call_some_C_function();
/// final str = CharArray.fromNative(p);
/// ```
final class CharArray {
  int _size;
  int _len;
  ffi.Pointer<ffi.Char> _buf;

  CharArray({int size = 32})
      : _size = size,
        _len = 0,
        _buf = calloc.allocate<ffi.Char>(size * ffi.sizeOf<ffi.Char>());

  /// Create newly a buffer for an existing Dart string.
  factory CharArray.from(String str) {
    final buf = _fillChars(str, (size) => CharArray(size: size));
    return buf;
  }

  /// A helper function that converts the given Dart String to `const char *`
  /// with an existing `CharArray`.
  /// The capacity is expanded automatically.
  ffi.Pointer<ffi.Char> pavedBy(String str) {
    _fillChars(str, (size) => this.._resize(size));
    return _buf;
  }

  int get length => _len;

  ffi.Pointer<ffi.Char> get pointer => _buf;

  /// Convert to Dart string with data in current buf and specified length.
  String get dartString => _buf.cast<Utf8>().toDartString(length: _len);

  bool _resize(int size) {
    if (size <= _size) {
      return false;
    }
    dispose();
    _buf = calloc.allocate<ffi.Char>(size * ffi.sizeOf<ffi.Char>());
    _size = size;
    // copy existing elements?
    _len = 0;
    return true;
  }

  /// Convert to Dart string with extern CString pointer without length.
  static String toDartString(ffi.Pointer<ffi.Char> pointer) =>
      pointer.cast<Utf8>().toDartString();

  /// Release native resources.
  void dispose() {
    calloc.free(_buf);
    _len = 0;
    _size = 0;
  }
}
