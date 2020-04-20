part of building_blocs;

/// Widget used to make a bloc instance easily accessible to child widgets
/// The bloc instance first passed to the stateful element is kept within the widget state,
/// it is not replaced duirng rebuild.
/// An inherited widget is created internally to provide efficient lookup using
/// BlocProvider.of<BlocType>(context)
class BlocProvider<T extends BaseBloc> extends StatefulWidget {
  final T Function() blocBuilder;
  final Widget child;

  BlocProvider({@required this.blocBuilder, @required this.child});

  /// Use this method to obtain a view model of a given type.
  static T of<T extends BaseBloc>(BuildContext context) {
    _BlocInherited<T> inherited = context.dependOnInheritedWidgetOfExactType<_BlocInherited<T>>();
    return inherited.bloc;
  }

  @override
  _BlocProviderState<T> createState() => new _BlocProviderState<T>();
}

class _BlocProviderState<T extends BaseBloc> extends State<BlocProvider> {

  T bloc;

  @override
  void initState() {
    bloc = widget.blocBuilder();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new _BlocInherited<T>(
      bloc: bloc,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    super.dispose();
    bloc.dispose();
  }
}

class _BlocInherited<T extends BaseBloc> extends InheritedWidget {
  final T bloc;

  _BlocInherited({Key key, this.bloc, Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_BlocInherited<T> old) {
    return true;
  }
}