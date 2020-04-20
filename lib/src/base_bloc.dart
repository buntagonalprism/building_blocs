part of building_blocs;
/// Base class for defining blocs. When blocs are supplied using the [BlocProvider], 
/// the [dispose] method of the bloc is called when the bloc is being destroyed, 
/// allowing tidy-up to be performed and resources released. [BaseBloc] also includes
/// methods for creating controllers for the two types of streams commonly handled by 
/// blocs: event and data streams. When created by the BaseBloc, the controllers will 
/// be automatically closed when the bloc is disposed. 
class BaseBloc {

  final List<StreamController> _eventControllers = [];
  final List<DataStreamController> _dataControllers = [];

  /// When used with a [BlocProvider], the dispose method of the bloc is is automatically 
  /// called when the provider is disposed, allowing the bloc to perform clean-up operations. 
  /// Override this function to implement tidy up in your bloc. 
  @mustCallSuper
  void dispose() {
    for (var eventController in _eventControllers) {
      eventController.close();
    }
    _eventControllers.clear();
    for (var dataController in _dataControllers) {
      dataController.dispose();
    }
    _dataControllers.clear();
  }

  /// Create a stream for emitting events, that will be automatically closed when the bloc is disposed. 
  StreamController<T> newEventStream<T>({void onListen(), void onCancel(), bool sync: false}) {
    final controller = StreamController.broadcast(onListen: onListen, onCancel: onCancel, sync: sync);
    _eventControllers.add(controller);
    return controller;
  }

  /// Create a data stream that will be automatically closed when the bloc is disposed
  DataStreamController<T> newDataStream<T>({void onListen(), void onCancel()}) {
    final controller = DataStreamController<T>(onListen: onListen, onCancel: onCancel);
    _dataControllers.add(controller);
    return controller;
  }


  /// Create a data stream with a seed value that will be automatically closed when the bloc is disposed
  DataStreamController<T> newSeededDataStream<T>({@required T seedValue, void onListen(), void onCancel()}) {
    final controller = DataStreamController<T>.seeded(seed: seedValue, onListen: onListen, onCancel: onCancel);
    _dataControllers.add(controller);
    return controller;
  }
}