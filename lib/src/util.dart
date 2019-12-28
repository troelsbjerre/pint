import 'dart:collection';
import 'dart:convert';

T TODO<T>() => throw 'Functionality not implemented.';

BigInt B(int i) => BigInt.from(i);

BigInt B0 = BigInt.zero;
BigInt B1 = BigInt.one;
BigInt BM1 = B(-1);
BigInt B2 = B(2);
BigInt B3 = B(3);
BigInt B4 = B(4);
BigInt B10 = B(10);

extension StreamLines on Stream<List<int>> {
  Stream<String> get lines =>
      transform(Utf8Decoder()).transform(LineSplitter());
}

class DefaultValueMapWrapper<K, V> extends MapBase<K, V> {
  V defaultValue;
  Map<K, V> wrapped;

  DefaultValueMapWrapper(this.wrapped, this.defaultValue);

  @override
  V operator [](Object key) => wrapped[key] ?? defaultValue;

  @override
  void operator []=(Object key, V value) => wrapped[key] = value;

  @override
  Iterable<K> get keys => wrapped.keys;

  @override
  V remove(Object key) => wrapped.remove(key);

  @override
  void clear() => wrapped.clear();
}
