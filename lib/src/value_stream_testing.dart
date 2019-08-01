part of building_blocs;


Type blocProviderType<T extends BaseBloc>(T mockBloc) {
  return BlocProvider(
    blocBuilder: () => mockBloc,
    child: Container(),
  ).runtimeType;
}


class TestValueStreamController<T> {
  final _controller = StreamController<T>.broadcast();
  ValueStream _valueStream;

  TestValueStreamController() {
   _valueStream = ValueStream(_controller.stream);
  }

  Future add(WidgetTester tester, T data) {
    _controller.add(data);
    return _doublePump(tester);
  }

  Future addError(WidgetTester tester, Object error) {
    _controller.addError(error);
    return _doublePump(tester);
  }
  Future _doublePump(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }
  ValueStream<T> get broadcastStream => _valueStream;
}