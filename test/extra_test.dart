import 'package:aiscript/aiscript.dart';
import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('FizzBuzz', () async {
    final res = await exec('''
      let res = []
      for (let i = 1, 15) {
        let msg =
          if (i % 15 == 0) "FizzBuzz"
          elif (i % 3 == 0) "Fizz"
          elif (i % 5 == 0) "Buzz"
          else i
        res.push(msg)
      }
      <: res
    ''');
    expect(res, HasValue([
      NumValue(1),
      NumValue(2),
      StrValue('Fizz'),
      NumValue(4),
      StrValue('Buzz'),
      StrValue('Fizz'),
      NumValue(7),
      NumValue(8),
      StrValue('Fizz'),
      StrValue('Buzz'),
      NumValue(11),
      StrValue('Fizz'),
      NumValue(13),
      NumValue(14),
      StrValue('FizzBuzz'),
    ]));
  });

  test('SKI', () async {
    final res = await exec('''
      let s = @(x) { @(y) { @(z) {
        //let f = x(z) f(@(a){ let g = y(z) g(a) })
        let f = x(z)
        f(y(z))
      }}}
      let k = @(x){ @(y) { x } }
      let i = @(x){ x }

      // combine
      @c(l) {
        // extract
        @x(v) {
          if (Core:type(v) == "arr") { c(v) } else { v }
        }

        // rec
        @r(f, n) {
          if (n < l.len) {
            r(f(x(l[n])), (n + 1))
          } else { f }
        }

        r(x(l[0]), 1)
      }

      let sksik = [s, [k, [s, i]], k]
      c([sksik, "foo", print])
    ''');
    expect(res, StrValue('foo'));
  });
  test('RuntimeError preserves the wrapped ScopeException', () async {
    // 未定義変数がどれだったかを、メッセージ文字列を parse せずに
    // 取り出せること。ホスト側が失敗を分類するのに必要 (pooza/capsicum#830)。
    try {
      await exec('<: undefinedVariable');
      fail('should have thrown');
    } on RuntimeError catch (e) {
      final cause = e.cause;
      expect(cause, isA<NoSuchVariableException>());
      expect((cause! as NoSuchVariableException).key, 'undefinedVariable');
    }
  });
}
