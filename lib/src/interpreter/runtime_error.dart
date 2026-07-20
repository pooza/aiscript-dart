import '../core/error.dart';
import '../core/line_column.dart';
import 'context.dart';

/// A runtime error.
class RuntimeError extends AiScriptError {
  RuntimeError(this.context, String message, [LineColumn? pos, this.cause])
      : super(message, pos);

  /// The execution context in which the error occurred.
  final Context context;

  /// The original exception, when this error wraps a more specific one
  /// (e.g. a [ScopeException] such as `NoSuchVariableException`).
  ///
  /// The wrapping is lossy without this: the message is stringified and
  /// callers can no longer tell *which* variable was missing without parsing
  /// the message. Host applications need that to classify failures — see
  /// `tool/flash_compat_check.dart` in pooza/capsicum.
  final Object? cause;

  @override
  String get type => 'RuntimeError';

  @override
  String toString() =>
      '${super.toString()}${context.moduleName == null ? '' : ' [in module "${context.moduleName}"]'}';
}

/// An index out of range error.
class IndexOutOfRangeError extends RuntimeError {
  IndexOutOfRangeError(Context context, int index, int length, [LineColumn? pos])
  : super(context, 'index out of range (index: $index, length: $length)', pos);
}