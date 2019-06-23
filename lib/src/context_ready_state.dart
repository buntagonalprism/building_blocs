part of '../building_blocs.dart';

/// Implementation of [State] for stateful widgets, that exposes the [onContextReady] method that
/// can be run during initialisation of the state once the BuildContext is ready. This allows the
/// context to be used to look up inherited widgets, such as blocs from a BlocProvider.
abstract class ContextReadyState<T extends StatefulWidget> extends State<T> {
  bool _hasInit = false;

  /// Called exactly once in the lifecycle of the [State] belonging to a [StatefulWidget].
  /// Here, the [context] of the state is valid, so it can be used to look up [InheritedWidget]
  /// parents.
  void onContextReady();

  @override
  @mustCallSuper
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasInit) {
      onContextReady();
      _hasInit = true;
    }
  }
}