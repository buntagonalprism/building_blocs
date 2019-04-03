
part of building_blocs;

/// A simple wrapper around the flutter native StreamBuilder that accepts a
/// ValueStream, and automatically uses the value from the ValueStream as the
/// initial data for the first pass build.
///
/// Stream builders by design do a build using the supplied initial data, before
/// any events from the data stream are received.
class ValueStreamBuilder<T> extends StatelessWidget {

  final ValueStream<T> valueStream;
  final AsyncWidgetBuilder<T> builder;
  ValueStreamBuilder({@required this.valueStream, @required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: valueStream.stream,
      initialData: valueStream.value,
      builder: builder,
    );
  }
}
