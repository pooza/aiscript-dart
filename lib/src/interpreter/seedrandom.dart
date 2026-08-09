/// seedrandom 3.0.5 (David Bau, MIT) の ARC4 生成器を Dart へ移植したもの。
///
/// 本家 aiscript の `Math:gen_rng` は `seedrandom(seed.toString())` を使う。
/// 一方このフォークは長らく文字列シードを Dart の `String.hashCode` で int に
/// 潰して `Random(int)` に渡していたため、**同じシードでも本家 Misskey と出目が
/// 一致しなかった**（pooza/capsicum#896）。ここを本家と同じアルゴリズムに揃える。
///
/// 照合先は **aiscript 0.19.0**（`seedrandom: 3.0.5`）。Misskey Web は
/// `getIsLegacy(version)` で 1.0.0 未満の Play を 0.19.0 の評価器へ回すため、
/// capsicum が実行しうる Play の Web 側実行系は常にこちらになる。
///
/// 移植にあたっての注意:
/// - `charCodeAt` は UTF-16 コードユニットを返す。Dart の `String.codeUnits` と
///   一致するので、サロゲートペアの扱いまで含めて素直に対応する。
/// - `prng()` の桁合わせは JS の**倍精度演算そのまま**でなければならない。整数で
///   代用すると丸めの入り方が変わって出目がずれるため、[double] で持つ。
library;

const int _width = 256;
const int _chunks = 6;
const int _mask = _width - 1;

/// 2^48。`arc4.g(6)` の取りうる値の上限＝初期の分母。
const double _startDenom = 281474976710656.0;

/// 2^52。倍精度の有効桁を埋めきったかの判定に使う。
const double _significance = 4503599627370496.0;

/// 2^53。丸め上げを避けるための上限。
const double _overflow = 9007199254740992.0;

/// seedrandom 互換の擬似乱数生成器。
///
/// [next] が JS の `prng()` に対応し、`[0, 1)` の倍精度を返す。
class SeedRandom {
  SeedRandom(String seed) : _arc4 = _Arc4(_mixkey(seed));

  final _Arc4 _arc4;

  /// JS の `prng()`。`[0, 1)` の倍精度を返す。
  double next() {
    var n = _arc4.g(_chunks).toDouble();
    var d = _startDenom;
    var x = 0;
    while (n < _significance) {
      n = (n + x) * _width;
      d *= _width;
      x = _arc4.g(1);
    }
    while (n >= _overflow) {
      n /= 2;
      d /= 2;
      // JS の `x >>>= 1`。x は 0..255 なので符号は問題にならない。
      x >>= 1;
    }
    return (n + x) / d;
  }

  /// `Math:gen_rng` が返す関数の整数版。本家の式
  /// `Math.floor(rng() * (floor(max) - ceil(min) + 1) + ceil(min))` をそのまま写す。
  /// 分布だけ合わせた別式にすると、同じ乱数列でも出目が変わる。
  int nextInRange(num min, num max) {
    final lo = min.ceil();
    final hi = max.floor();
    return (next() * (hi - lo + 1) + lo).floor();
  }
}

/// seedrandom の `mixkey(flatten(seed, 3), [])`。
///
/// [seed] が文字列のとき `flatten` は恒等なので、ここでは文字列だけを受ける。
List<int> _mixkey(String seed) {
  final key = <int>[];
  // JS では `smear` が undefined から始まり、未代入の `key[j]` は
  // `undefined * 19 = NaN` になる。`smear ^= NaN` は ToInt32 を通って 0 なので、
  // 256 文字目までは smear が 0 のまま＝コードユニットをそのまま詰めるのと同じ。
  var smear = 0;
  for (var j = 0; j < seed.length; j++) {
    final index = _mask & j;
    if (index < key.length) {
      // 2 周目以降。ここで初めて smear が効く。
      smear ^= key[index] * 19;
      key[index] = _mask & (smear + seed.codeUnitAt(j));
    } else {
      key.add(_mask & seed.codeUnitAt(j));
    }
  }
  return key;
}

/// seedrandom の ARC4。コンストラクタの末尾で `g(256)` を捨てる（RC4-drop[256]）。
class _Arc4 {
  _Arc4(List<int> key) {
    // 空のキーは [0] として扱う。
    final k = key.isEmpty ? <int>[0] : key;
    for (var i = 0; i < _width; i++) {
      _s.add(i);
    }
    var j = 0;
    for (var i = 0; i < _width; i++) {
      final t = _s[i];
      j = _mask & (j + k[i % k.length] + t);
      _s[i] = _s[j];
      _s[j] = t;
    }
    g(_width);
  }

  final List<int> _s = [];
  int _i = 0;
  int _j = 0;

  /// 次の [count] 出力を 1 つの数に連結して返す（`0 <= r < 256^count`）。
  int g(int count) {
    var r = 0;
    var i = _i;
    var j = _j;
    for (var c = 0; c < count; c++) {
      i = _mask & (i + 1);
      final t = _s[i];
      j = _mask & (j + t);
      // JS の `s[mask & ((s[i] = s[j]) + (s[j] = t))]` は、左から
      // 「元の s[j] を s[i] へ」「t を s[j] へ」の順に評価し、その 2 値の和を
      // 添字にする。入れ替え後の配列を読む点に注意。
      final sj = _s[j];
      _s[i] = sj;
      _s[j] = t;
      r = r * _width + _s[_mask & (sj + t)];
    }
    _i = i;
    _j = j;
    return r;
  }
}
