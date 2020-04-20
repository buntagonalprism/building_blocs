part of building_blocs;

/// Simple wrapper around an error that includes a stack trace as well as the error.
/// This allows a StreamBuilder to get access to the stack trace as well for crash-logging, as
/// normally the AsyncSnapshot.error value is just the error and the stack trace is lost.
class ErrorTrace extends Equatable {
  final Object error;
  final StackTrace trace;

  ErrorTrace(this.error, this.trace);

  @override
  List<Object> get props => [error, trace];

  @override
  String toString() {
    return error.toString();
  }
}

/// A thin wrapper around a stream controller that allows a Bloc to create an data stream it
/// may publish events on, which can be exposed publicly as a read-only DataStream for the UI
/// to consume.
class DataStreamController<T> extends DataStream<T> {
  bool _hasAdded = false;
  T _value;
  ErrorTrace _error;
  StreamController<T> _subject;

  DataStreamController({VoidCallback onListen, VoidCallback onCancel}) {
    _subject = StreamController<T>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
    );
  }

  /// Specify an initial seed value
  DataStreamController.seeded({@required T seed, VoidCallback onListen, VoidCallback onCancel}) {
    _hasAdded = true;
    _value = seed;
    _subject = StreamController<T>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
    );
    _subject.add(seed);
  }

  @override
  void dispose() {
    _subject.close();
  }

  @override
  Stream<T> get stream => _subject.stream;

  @override
  T get value => _value;

  @override
  ErrorTrace get error => _error;

  void add(T data) {
    _value = data;
    _error = null;
    _hasAdded = true;
    _subject.add(data);
  }

  void addError(dynamic error, [StackTrace trace]) {
    ErrorTrace et;
    if (error is ErrorTrace) {
      et = error;
    } else {
      et = ErrorTrace(error, trace);
    }
    _error = et;
    _subject.addError(et);
  }

  /// Reset the state of the value stream as though no data had been added, setting the value
  /// to null and hasAddedValue to false.
  void reset() {
    _value = null;
    _hasAdded = false;
  }

  @override
  bool get hasAddedValue => _hasAdded;
}

/// [DataStream] provides access to the latest value delivered by a source stream. The base
/// interface does not expose any [StreamController] operations, making it ideal as an output-only
/// data type.
///
/// [DataStream] by default only listens to a source stream when the [DataStream] itself has
/// listeners. This saves resources, although may mean data is out of date when listeners
/// resubscribe.
///
/// To ensure [DataStream] always has up to date data from a source stream, create it with
/// keepAlive: true. If this is done, dispose must be called when the stream is no longer needed,
/// to release the inner subscription that was created.
///
/// Errors in the stream are always emitted as [ErrorTrace] objects which include both the error
/// and stack trace, if available. This is useful when receiving an AsyncSnapshot.error in a
/// stream builder, since the snapshot does not otherwise expose the trace. If the last item
/// emitted by the stream was an error, it is available in the [error] property. The value of
/// [error] is reset to null every time a value is added.
///
/// Keep alive is not necessary when wrapping Firestore queries, since by default they perform a
/// fetch of the latest data and attach data observers as soon as the first listener subscribes.
/// However, keepAlive may be useful to prevent Firestore from triggering extra network fetches and
/// UI rebuilds when listeners are being regularly destroyed and recreated, such as when switching
/// between tabs.
abstract class DataStream<T> {
  DataStream();

  /// The latest value delivered by the stream
  T get value;

  /// The latest error delivered by the stream. Whenever a new value is emitted, error will be reset
  /// back to null.
  ErrorTrace get error;

  /// The stream of data.
  Stream<T> get stream;

  /// Inform the DataStream that it can shut down - only required when created with keepAlive: true
  void dispose();

  /// Whether this DataStream a value added to it. Set when a value is added from any source, or
  /// if seeded with a value. Can be used to differentiate an uninitialised value of null from a
  /// deliberately seeded / initial value of null.
  bool get hasAddedValue;

  /// Run a function immediately with the current value, if one has been added, and subscribe that
  /// same function to the stream. If a value has not been added, runs the function with the value
  /// of seed instead, if provided. Useful for performing initialisation in an initState.
  StreamSubscription<T> runAndListen(void Function(T event) onData,
      {Function onError, void Function() onDone, bool cancelOnError, T seed}) {
    if (hasAddedValue) {
      onData(value);
    } else if (seed != null) {
      onData(seed);
    }
    return stream.listen(onData, onDone: onDone, onError: onError, cancelOnError: cancelOnError);
  }

  DataStream<S> map<S>(S convert(T event)) {
    StreamController<S> controller;
    StreamSubscription<T> subscription;
    T lastConverted;
    controller = StreamController<S>.broadcast(
      onListen: () {
        if (this.value != lastConverted) {
          lastConverted = this.value;
          controller.add(convert(this.value));
        }
        subscription = this.stream.listen((T data) {
          lastConverted = data;
          controller.add(convert(data));
        }, onError: (e, t) {
          controller.addError(e, t);
        }, onDone: () {
          controller.close();
        });
      },
      onCancel: () {
        subscription.cancel();
      },
    );

    if (hasAddedValue) {
      lastConverted = this.value;
      return DataStream.seeded(controller.stream, seed: convert(this.value));
    } else {
      return DataStream.of(controller.stream);
    }
  }

  /// Build a widget from a [DataStream].
  ///
  /// Uses the [value] of the value stream to perform the, if a value is available.
  ///
  /// Rebuilds itself whenever the stream emits a value or error event.
  ///
  /// If the DataStream has an error, then [builder] will be callved with an AsyncSnapshot.error.
  /// This also happens on the first build.
  static Widget builder<B>({
    Key key,
    @required DataStream<B> stream,
    @required AsyncWidgetBuilder<B> builder,
  }) {
    return StreamBuilder<B>(
      key: key,
      initialData: stream.value,
      stream: stream.stream,
      builder: (BuildContext context, AsyncSnapshot<B> snapshot) {
        if (stream.error != null) {
          final AsyncSnapshot<B> errorSnapshot =
              AsyncSnapshot.withError(snapshot.connectionState, stream.error);
          return builder(context, errorSnapshot);
        } else if (stream.hasAddedValue) {
          final AsyncSnapshot<B> valueSnapshot =
              AsyncSnapshot.withData(snapshot.connectionState, stream.value);
          return builder(context, valueSnapshot);
        } else {
          return builder(context, snapshot);
        }
      },
    );
  }

  /// Create a new DataStream wrapped around an existing stream.
  factory DataStream.of(Stream<T> source, {bool keepAlive = false}) {
    return _DataStream.fromStream(source, keepAlive: keepAlive, hasSeedValue: false);
  }

  factory DataStream.seeded(Stream<T> source, {@required T seed, bool keepAlive = false}) {
    return _DataStream.fromStream(
      source,
      hasSeedValue: true,
      seedValue: seed,
      keepAlive: keepAlive,
    );
  }

  /// Construct a new keep-alive value stream wrapped around this one
  DataStream<T> keepAlive() {
    if (hasAddedValue) {
      return DataStream.seeded(stream, seed: value, keepAlive: true);
    } else {
      return DataStream.of(stream, keepAlive: true);
    }
  }

  /// The following combineLatestX functions all work similarly to the equivalent functions of
  /// [Observable], with the only difference being returning a DataStream instead.
  static DataStream<R> combineLatest2<A, B, R>(
      DataStream<A> streamOne, DataStream<B> streamTwo, R combiner(A a, B b),
      {bool keepAlive = false}) {
    return _buildCombinerDataStream(
      [streamOne, streamTwo],
      (List<dynamic> values) => combiner(values[0] as A, values[1] as B),
      keepAlive: keepAlive,
    );
  }

  static DataStream<R> combineLatest3<A, B, C, R>(DataStream<A> streamA, DataStream<B> streamB,
      DataStream<C> streamC, R combiner(A a, B b, C c),
      {bool keepAlive = false}) {
    return _buildCombinerDataStream(
      [streamA, streamB, streamC],
      (List<dynamic> values) {
        return combiner(
          values[0] as A,
          values[1] as B,
          values[2] as C,
        );
      },
      keepAlive: keepAlive,
    );
  }

  static DataStream<R> combineLatest4<A, B, C, D, R>(
      DataStream<A> streamA,
      DataStream<B> streamB,
      DataStream<C> streamC,
      DataStream<D> streamD,
      R combiner(A a, B b, C c, D d),
      {bool keepAlive = false}) {
    return _buildCombinerDataStream(
      [streamA, streamB, streamC, streamD],
      (List<dynamic> values) {
        return combiner(
          values[0] as A,
          values[1] as B,
          values[2] as C,
          values[3] as D,
        );
      },
      keepAlive: keepAlive,
    );
  }

  static DataStream<R> combineLatest5<A, B, C, D, E, R>(
      DataStream<A> streamA,
      DataStream<B> streamB,
      DataStream<C> streamC,
      DataStream<D> streamD,
      DataStream<E> streamE,
      R combiner(A a, B b, C c, D d, E e),
      {bool keepAlive = false}) {
    return _buildCombinerDataStream(
      [streamA, streamB, streamC, streamD, streamE],
      (List<dynamic> values) {
        return combiner(
          values[0] as A,
          values[1] as B,
          values[2] as C,
          values[3] as D,
          values[4] as E,
        );
      },
      keepAlive: keepAlive,
    );
  }

  static DataStream<R> combineLatest6<A, B, C, D, E, F, R>(
      DataStream<A> streamA,
      DataStream<B> streamB,
      DataStream<C> streamC,
      DataStream<D> streamD,
      DataStream<E> streamE,
      DataStream<F> streamF,
      R combiner(A a, B b, C c, D d, E e, F f),
      {bool keepAlive = false}) {
    return _buildCombinerDataStream(
      [streamA, streamB, streamC, streamD, streamE, streamF],
      (List<dynamic> values) {
        return combiner(
          values[0] as A,
          values[1] as B,
          values[2] as C,
          values[3] as D,
          values[4] as E,
          values[5] as F,
        );
      },
      keepAlive: keepAlive,
    );
  }

  static DataStream<R> combineLatest7<A, B, C, D, E, F, G, R>(
      DataStream<A> streamA,
      DataStream<B> streamB,
      DataStream<C> streamC,
      DataStream<D> streamD,
      DataStream<E> streamE,
      DataStream<F> streamF,
      DataStream<G> streamG,
      R combiner(A a, B b, C c, D d, E e, F f, G g),
      {bool keepAlive = false}) {
    return _buildCombinerDataStream(
      [streamA, streamB, streamC, streamD, streamE, streamF, streamG],
      (List<dynamic> values) {
        return combiner(
          values[0] as A,
          values[1] as B,
          values[2] as C,
          values[3] as D,
          values[4] as E,
          values[5] as F,
          values[6] as G,
        );
      },
      keepAlive: keepAlive,
    );
  }

  static DataStream<R> combineLatest8<A, B, C, D, E, F, G, H, R>(
      DataStream<A> streamA,
      DataStream<B> streamB,
      DataStream<C> streamC,
      DataStream<D> streamD,
      DataStream<E> streamE,
      DataStream<F> streamF,
      DataStream<G> streamG,
      DataStream<H> streamH,
      R combiner(A a, B b, C c, D d, E e, F f, G g, H h),
      {bool keepAlive = false}) {
    return _buildCombinerDataStream(
      [streamA, streamB, streamC, streamD, streamE, streamF, streamG, streamH],
      (List<dynamic> values) {
        return combiner(
          values[0] as A,
          values[1] as B,
          values[2] as C,
          values[3] as D,
          values[4] as E,
          values[5] as F,
          values[6] as G,
          values[7] as H,
        );
      },
      keepAlive: keepAlive,
    );
  }

  static DataStream<R> combineLatest9<A, B, C, D, E, F, G, H, I, R>(
      DataStream<A> streamA,
      DataStream<B> streamB,
      DataStream<C> streamC,
      DataStream<D> streamD,
      DataStream<E> streamE,
      DataStream<F> streamF,
      DataStream<G> streamG,
      DataStream<H> streamH,
      DataStream<I> streamI,
      R combiner(A a, B b, C c, D d, E e, F f, G g, H h, I i),
      {bool keepAlive = false}) {
    return _buildCombinerDataStream(
      [streamA, streamB, streamC, streamD, streamE, streamF, streamG, streamH, streamI],
      (List<dynamic> values) {
        return combiner(
          values[0] as A,
          values[1] as B,
          values[2] as C,
          values[3] as D,
          values[4] as E,
          values[5] as F,
          values[6] as G,
          values[7] as H,
          values[8] as I,
        );
      },
      keepAlive: keepAlive,
    );
  }
}

class _DataStream<T> extends DataStream<T> {
  final Stream<T> source;

  bool _keepAlive;
  bool _hasAddedValue = false;
  T _value;
  ErrorTrace _error;
  StreamController<T> _controller;
  StreamSubscription<T> _innerSubscription; // ignore: cancel_subscriptions

  @override
  Stream<T> get stream => _controller.stream;

  @override
  T get value => _value;

  @override
  ErrorTrace get error => _error;

  _DataStream.fromStream(this.source, {bool keepAlive, bool hasSeedValue, T seedValue}) {
    _keepAlive = keepAlive == true;
    _controller = StreamController<T>.broadcast(
      onListen: _setupInnerSubscription,
      onCancel: _cancelInnerSubscription,
    );
    if (hasSeedValue) {
      _value = seedValue;
      _hasAddedValue = true;
    }
    if (keepAlive) {
      _setupInnerSubscription();
    }
  }

  void _setupInnerSubscription() {
    if (_innerSubscription == null && source != null) {
      _innerSubscription = source.listen((data) {
        _hasAddedValue = true;
        _error = null;
        _value = data;
        _controller.add(data);
      }, onError: (error, trace) {
        ErrorTrace et;
        if (error is ErrorTrace) {
          et = error;
        } else {
          et = ErrorTrace(error, trace);
        }
        _error = et;
        _controller.addError(et, trace);
      }, onDone: () {
        _controller.close();
      });
    }
  }

  Future<dynamic> _cancelInnerSubscription() async {
    if (!_keepAlive && _innerSubscription != null) {
      /// It is important to null out our inner subscription reference BEFORE
      /// cancelling it, so that this stream is able to be immediately
      /// re-subscribed to.
      final temp = _innerSubscription;
      _innerSubscription = null;
      await temp.cancel();
    }
    return;
  }

  @override
  Future dispose() {
    _keepAlive = false;
    return _cancelInnerSubscription();
  }

  @override
  bool get hasAddedValue => _hasAddedValue;
}

DataStream<R> _buildCombinerDataStream<T, R>(
    Iterable<DataStream<T>> streams, R combiner(List<T> values),
    {bool keepAlive = false}) {
  final subscriptions = List<StreamSubscription<dynamic>>(streams.length);
  StreamController<R> controller;

  List<T> lastCombinedValues;

  bool hasSeedValue = false;
  R seedValue;
  if (streams.every((vs) => vs.hasAddedValue)) {
    hasSeedValue = true;
    lastCombinedValues = streams.map((vs) => vs.value).toList();
    seedValue = combiner(lastCombinedValues);
  }

  DataStream<R> vsOutput;
  controller = StreamController<R>.broadcast(
    sync: true,
    onListen: () {
      final values = List<T>(streams.length);
      final triggered = List.generate(streams.length, (_) => false);
      final completedStatus = List.generate(streams.length, (_) => false);
      var allStreamsHaveEvents = false;

      for (var i = 0, len = streams.length; i < len; i++) {
        final stream = streams.elementAt(i);

        /// If a stream now has an error different to the combined, output it
        if (stream.error != null && vsOutput.error != stream.error) {
          controller.addError(stream.error, stream.error.trace);
        }

        /// If a stream has a current value, it is considered as having emitted it from the point
        /// of view of waiting for all streams to have emitted a value before combining.
        else if (stream.hasAddedValue) {
          values[i] = stream.value;
          triggered[i] = true;
        }

        subscriptions[i] = stream.stream.listen(
          (T value) {
            values[i] = value;
            triggered[i] = true;

            if (!allStreamsHaveEvents) {
              allStreamsHaveEvents = triggered.every((t) => t);
            }

            if (allStreamsHaveEvents) {
              try {
                lastCombinedValues = values;
                controller.add(combiner(values));
              } catch (e, s) {
                controller.addError(ErrorTrace(e, s), s);
              }
            }
          },
          onError: (e, s) {
            ErrorTrace et;
            if (e is ErrorTrace) {
              et = e;
            } else {
              et = ErrorTrace(e, s);
            }
            controller.addError(et, s);
          },
          onDone: () {
            completedStatus[i] = true;
            if (completedStatus.every((c) => c)) controller.close();
          },
        );
      }
      if (streams.every((vs) => vs.hasAddedValue) && !streams.any((vs) => vs.error != null)) {
        if (!ListEquality().equals(lastCombinedValues, values)) {
          try {
            lastCombinedValues = values;
            controller.add(combiner(values));
          } catch (e, s) {
            controller.addError(ErrorTrace(e, s), s);
          }
        }
      }
    },
    onCancel: () => Future.wait<dynamic>(subscriptions
        .map((StreamSubscription<dynamic> subscription) => subscription.cancel())
        .where((Future<dynamic> cancelFuture) => cancelFuture != null)),
  );

  if (hasSeedValue) {
    vsOutput = DataStream.seeded(controller.stream, seed: seedValue, keepAlive: keepAlive);
  } else {
    vsOutput = DataStream.of(controller.stream, keepAlive: keepAlive);
  }
  return vsOutput;
}
