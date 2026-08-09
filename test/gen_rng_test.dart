import 'package:aiscript/aiscript.dart';
import 'package:aiscript/src/interpreter/seedrandom.dart';
import 'package:test/test.dart';
import 'utils.dart';

/// `Math:gen_rng` を本家 aiscript 0.19.0（`seedrandom` 3.0.5）と一致させるための
/// 固定 (pooza/capsicum#896)。
///
/// 期待値は本物の seedrandom 3.0.5 を Node で回して採った実測値。ここが落ちる
/// ときは移植のどこかが本家からずれており、**シードを固定しても Misskey Web と
/// 出目が一致しない**状態に戻っている。
///
/// 生成用スクリプト:
/// ```js
/// const seedrandom = require('seedrandom');
/// const rng = seedrandom('seed_fixed');
/// for (let i = 0; i < 5; i++) console.log(rng().toPrecision(17));
/// ```
void main() {
  group('SeedRandom (seedrandom 3.0.5 互換)', () {
    test('文字列シードの生の出力が本家と一致する', () {
      final rng = SeedRandom('seed_fixed');
      expect(
        [for (var i = 0; i < 5; i++) rng.next()],
        [
          0.43959379726787007,
          0.15508194949917534,
          0.19920046775858524,
          0.67473719208551941,
          0.074652379749868145,
        ],
      );
    });

    test('空のシード（ARC4 のキーが空になる経路）', () {
      final rng = SeedRandom('');
      expect(rng.next(), 0.23144008215179881);
    });

    test('非 ASCII シード（UTF-16 コードユニットで混ぜる）', () {
      final rng = SeedRandom('あ');
      expect(rng.next(), 0.42224638432255929);
    });

    test('同じシードなら何度作っても同じ列', () {
      final first = [for (var i = 0; i < 3; i++) SeedRandom('same').next()];
      expect(first, everyElement(first.first));
    });
  });

  group('Math:gen_rng (#896)', () {
    /// シードから整数を [count] 個引いてカンマ区切りで返す。
    /// 本家の式 `floor(rng() * (floor(max) - ceil(min) + 1) + ceil(min))` を
    /// 通した値になる。
    Future<List<int>> ints(String seedExpr, int count) async {
      final res = await exec('''
        let r = Math:gen_rng($seedExpr)
        var s = ""
        for (let i, $count) {
          s = `{s},{r(0 100000)}`
        }
        <: s
      ''');
      final raw = (res as StrValue).value;
      return [
        for (final part in raw.split(',').where((p) => p.isNotEmpty))
          int.parse(part),
      ];
    }

    test('実際の Play が使う形のシード', () async {
      expect(
        await ints('"user12345_2026_7_26_comfy_slot"', 5),
        [51954, 23544, 4594, 30169, 42535],
      );
    });

    test('短いシード', () async {
      expect(await ints('"seed_fixed"', 5), [43959, 15508, 19920, 67474, 7465]);
    });

    test('256 文字ちょうど（キーが一周する境界）', () async {
      expect(await ints('"${'x' * 256}"', 5), [90807, 74359, 74467, 39917, 17929]);
    });

    test('256 文字を超えるシード（smear が効き始める経路）', () async {
      expect(await ints('"${'a' * 300}"', 5), [78967, 46838, 23467, 16372, 7711]);
    });

    test('数値シードは JS と同じ文字列化を経る', () async {
      // 本家は seed.value.toString() を渡すので、5 は "5" と等価でなければ
      // ならない。Dart の double.toString() は "5.0" になるため吸収している。
      expect(await ints('5', 5), [7790, 71777, 69339, 58096, 31513]);
      expect(await ints('"5"', 5), [7790, 71777, 69339, 58096, 31513]);
    });

    test('数値でも文字列でもないシードは null を返す（本家と同じ）', () async {
      final res = await exec('<: Core:type(Math:gen_rng([1, 2]))');
      expect(res, StrValue('null'));
    });
  });
}
