part of building_blocs;
/// Base class for defining blocs. When blocs are supplied using the [BlocProvider], 
/// the [dispose] method of the bloc is called when the bloc is being destroyed, 
/// allowing tidy-up to be performed and resources released. 
class BaseBloc {

  /// When used with a [BlocProvider], the dispose method of the bloc is is automatically 
  /// called when the provider is disposed, allowing the bloc to perform clean-up operations. 
  /// Override this function to implement tidy up in your bloc such as closing stream controllers
  void dispose() {}

}
