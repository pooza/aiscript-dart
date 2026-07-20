import 'value.dart';

final Map<String, Map<String, Value Function(Value)>> primitiveProps = {
  'num': {
    'to_str': (target) => NativeFnValue((_, __) async =>
        StrValue(target.cast<NumValue>().value.toString())
    )
  },

  'str': {
    'to_num': (target) => NativeFnValue((_, __) async {
      final value = num.parse(target.cast<StrValue>().value);
      return value.isNaN ? NullValue() : NumValue(value);
    }),

    'len': (target) => NumValue(_splitStr(target.cast<StrValue>().value).length),

    'replace': (target) => NativeFnValue((args, __) async {
      final value = target.cast<StrValue>().value;
      final from = args.check<StrValue>(0).value;
      final replace = args.check<StrValue>(1).value;
      return StrValue(value.replaceAll(from, replace));
    }),

    'index_of': (target) => NativeFnValue((args, __) async {
      final value = target.cast<StrValue>().value;
      final search = args.check<StrValue>(0).value;
      return NumValue(value.indexOf(search));
    }),

    'incl': (target) => NativeFnValue((args, __) async {
      final value = target.cast<StrValue>().value;
      final search = args.check<StrValue>(0).value;
      return BoolValue(value.contains(search));
    }),

    'trim': (target) => NativeFnValue((args, __) async =>
        StrValue(target.cast<StrValue>().value.trim())
    ),

    'upper': (target) => NativeFnValue((args, __) async =>
        StrValue(target.cast<StrValue>().value.toUpperCase())
    ),

    'lower': (target) => NativeFnValue((args, __) async =>
        StrValue(target.cast<StrValue>().value.toLowerCase())
    ),

    'split': (target) => NativeFnValue((args, __) async {
      final value = target.cast<StrValue>().value;
      final sep = args.isNotEmpty ? args.check<StrValue>(0).value : null;
      final arr = _splitStr(value, sep).map((e) => StrValue(e)).toList();
      return ArrValue(arr);
    }),

    'slice': (target) => NativeFnValue((args, __) async {
      final value = target.cast<StrValue>().value;
      final start = args.check<NumValue>(0).value;
      final end = args.check<NumValue>(1).value;
      final chars = _splitStr(value);
      final range = _clampRange(start, end, chars.length);
      return StrValue(chars.sublist(range.$1, range.$2).join());
    }),

    'pick': (target) => NativeFnValue((args, __) async {
      final value = target.cast<StrValue>().value;
      final i = args.check<NumValue>(0).value.toInt();

      final chars = _splitStr(value);

      return (i >= 0 && i < chars.length) ?
          StrValue(chars[i]) :
          NullValue();
    }),

    'codepoint_at': (target) => NativeFnValue((args, __) async {
      final value = target.cast<StrValue>().value;
      final i = args.check<NumValue>(0).value.toInt();

      return (i >= 0 && i < value.length) ?
          NumValue(value.codeUnitAt(i)) :
          NullValue();
    }),
  },

  'arr': {
    'len': (target) => NumValue(target.cast<ArrValue>().value.length),

    'push': (target) => NativeFnValue((args, __) async =>
        target.cast<ArrValue>()..value.add(args.check<Value>(0))
    ),

    'unshift': (target) => NativeFnValue((args, __) async =>
        target.cast<ArrValue>()..value.insert(0, args.check<Value>(0))
    ),

    'pop': (target) => NativeFnValue((_, __) async {
      final arr = target.cast<ArrValue>().value;
      return arr.isNotEmpty ? arr.removeLast() : NullValue();
    }),

    'shift': (target) => NativeFnValue((_, __) async {
      final arr = target.cast<ArrValue>().value;
      return arr.isNotEmpty ? arr.removeAt(0) : NullValue();
    }),

    'concat': (target) => NativeFnValue((args, __) async =>
        ArrValue(target.cast<ArrValue>().value + args.check<ArrValue>(0).value)
    ),

    'slice': (target) => NativeFnValue((args, __) async {
      final value = target.cast<ArrValue>().value;
      final start = args.check<NumValue>(0).value;
      final end = args.check<NumValue>(1).value;
      final range = _clampRange(start, end, value.length);
      return ArrValue(value.sublist(range.$1, range.$2));
    }),

    'join': (target) => NativeFnValue((args, __) async {
      final value = target.cast<ArrValue>().value;
      final sep = args.isNotEmpty ? args.check<StrValue>(0).value : '';
      return StrValue(value.map((e) => e is StrValue ? e.value : '').join(sep));
    }),

    'map': (target) => NativeFnValue((args, state) async {
      final value = target.cast<ArrValue>().value;
      final fn = args.check<FnValue>(0);

      var i = 0;
      final newArr = await Future.wait(
        value.map((item) => state.call(fn, args: [item, NumValue(i++)]))
      );

      return ArrValue(newArr.toList());
    }),

    'filter': (target) => NativeFnValue((args, state) async {
      final value = target.cast<ArrValue>().value;
      final fn = args.check<FnValue>(0);

      final List<Value> newArr = [];
      for (var i = 0; i < value.length; ++i) {
        final item = value[i];
        final res = await state.call(fn, args: [item, NumValue(i)]);
        final resValue = res.cast<BoolValue>().value;
        if (resValue) newArr.add(item);
      }

      return ArrValue(newArr);
    }),

    'reduce': (target) => NativeFnValue((args, state) async {
      final value = target.cast<ArrValue>().value;
      final fn = args.check<FnValue>(0);

      final arg1 = args.elementAtOrNull(1);
      final withInitVal = arg1 != null;

      var acc = withInitVal ? arg1 : value.elementAtOrNull(0);
      if (acc == null) return NullValue();

      for (var i = withInitVal ? 0 : 1; i < value.length; ++i) {
        acc = await state.call(fn, args: [acc!, value[i], NumValue(i)]);
      }

      return acc!;
    }),

    'find': (target) => NativeFnValue((args, state) async {
      final value = target.cast<ArrValue>().value;
      final fn = args.check<FnValue>(0);

      for (var i = 0; i < value.length; ++i) {
        final item = value[i];
        final res = await state.call(fn, args: [item, NumValue(i)]);
        final resValue = res.cast<BoolValue>().value;
        if (resValue) return item;
      }

      return NullValue();
    }),

    'incl': (target) => NativeFnValue((args, __) async {
      final value = target.cast<ArrValue>().value;
      final item = args.check<Value>(0);
      if (item is! PrimitiveValue) return BoolValue(false);

      return BoolValue(value.contains(item));
    }),

    'reverse': (target) => NativeFnValue((_, __) async {
      final value = target.cast<ArrValue>().value;
      
      for (var i = 0, j = value.length - 1; i < value.length ~/ 2; ++i, --j) {
        final tmp = value[i];
        value[i] = value[j];
        value[j] = tmp;
      }

      return NullValue();
    }),

    'copy': (target) => NativeFnValue((_, __) async =>
      ArrValue(List.from(target.cast<ArrValue>().value))
    ),

    'sort': (target) => NativeFnValue((args, state) async {
      final value = target.cast<ArrValue>().value;
      final fn = args.check<FnValue>(0);

      value.setAll(0, await _mergeSort(value, (a, b) async =>
          (await state.call(fn, args: [a, b]))
          .cast<NumValue>().value.toInt()
      ));

      return target;
    })
  },

  'error': {
    'name': (target) => StrValue(target.cast<ErrorValue>().value),

    'info': (target) => target.cast<ErrorValue>().info ?? NullValue(),
  }
};

Future<List<Value>> _mergeSort(List<Value> list, Future<int> Function(Value, Value) comp) async {
  if (list.length <= 1) return list;
  final mid = (list.length / 2).floor();
  final left = await _mergeSort(list.sublist(0, mid), comp);
  final right = await _mergeSort(list.sublist(mid), comp);
  return _merge(left, right, comp);
}

Future<List<Value>> _merge(List<Value> left, List<Value> right, Future<int> Function(Value, Value) comp) async {
  final List<Value> result = [];
  var leftIndex = 0;
  var rightIndex = 0;
  while (leftIndex < left.length && rightIndex < right.length) {
    final l = left[leftIndex];
    final r = right[rightIndex];
    final compValue = await comp(l, r);

    if (compValue < 0) {
      result.add(l);
      ++leftIndex;
    } else {
      result.add(r);
      ++rightIndex;
    }
  }
  return result + left.sublist(leftIndex) + right.sublist(rightIndex);
}

List<String> _splitStr(String str, [String? sep]) {
  if (sep != null && sep != '') return str.split(sep);

  List<String> chars = [];
  for (final rune in str.runes) {
    final char = String.fromCharCode(rune);
    if (_isEmojiModifier(rune)) {
      if (chars.isNotEmpty) {
        chars.last += char;
        continue;
      }
    }
    chars.add(char);
  }
  return chars;
}

bool _isEmojiModifier(int char) => char >= 0x1F3FB && char <= 0x1F3FF;

/// slice の範囲を JS `Array.prototype.slice` / `String.prototype.slice` 準拠で
/// 丸める。負値は末尾からのオフセットとして扱い、範囲外はクランプする。
///
/// 本家 (@syuilo/aiscript) は JS のメソッドをそのまま呼んでおり範囲外でも
/// 例外を投げないが、Dart の `sublist` は RangeError を投げるため補正が要る。
/// 実在の Flash スクリプト (pooza/capsicum#830) が `arr.slice(0 n)` を
/// 空配列に対して呼んでクラッシュしたことによる修正。
(int, int) _clampRange(num start, num end, int length) {
  int normalize(num v) {
    final i = v.toInt();
    return (i < 0 ? length + i : i).clamp(0, length);
  }

  final s = normalize(start);
  return (s, normalize(end).clamp(s, length));
}
