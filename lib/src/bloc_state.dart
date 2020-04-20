part of building_blocs;

/// State for widgets that use a bloc. Provides
/// - onContextReady for attaching to the bloc
/// - listen/runAndListen to subscribe to streams and automatically unsubscribe on dispose
abstract class BlocState<S extends StatefulWidget> extends ContextReadyState<S> {

  final List<StreamSubscription> _subscriptions = List<StreamSubscription>();

  void listenToEvents<T>(Stream<T> stream, void onData(T event), {Function onError}) {
    assert(stream.isBroadcast,
     """All event streams observed by BlocStates should be broadcast streams. 
      Otherwise errors can occur when widgets are destroyed and rebuilt and a
      attempt to listen to the stream again, e.g. as a result of switching between
      different tabs in a tab bar.
      """,
    );
    _subscriptions.add(stream.listen(onData, onError: onError));
  }

  void listenToData<T>(DataStream<T> stream, void onData(T data), {Function onError}) {
    _subscriptions.add(stream.runAndListen(onData, onError: onError));
  }

  @override
  void dispose() {
    super.dispose();
    for (StreamSubscription sub in _subscriptions) {
      sub.cancel();
    }
  }


}