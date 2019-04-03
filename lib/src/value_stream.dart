part of building_blocs;

/// A simple stream wrapper that makes available the last value output by the stream
/// When combined with ValueStreamBuilder, this avoids the single-frame flicker of
/// native StreamBuilder by always supplying initial data for the first build pass.
class ValueStream<T> {
  Stream<T> _stream;
  Stream<T> get stream => _stream;
  T _value;
  T get value => _value;
  ValueStream(Stream<T> sourceStream, [T initialData]) {
    _value = initialData;
    _stream = sourceStream.map((data) {
      _value = data;
      return data;
    });
  }
}