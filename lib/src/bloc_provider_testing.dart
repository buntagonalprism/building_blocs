part of building_blocs;

/// Use this to get an instance of a bloc provider runtime type
/// when running flutter tests. 
@visibleForTesting
Type blocProviderType<T extends BaseBloc>(T mockBloc) {	
  return BlocProvider(	
    blocBuilder: () => mockBloc,	
    child: Container(),	
  ).runtimeType;	
}

/// Use when testing to supply a mock bloc that should replace any attempts to 
/// reference a bloc of a particular type. The supplied override will be returned
/// for any call to [BlocProvider.of] that requests the target type. 
/// 
/// The override bloc will also be used to take the place of the output of the 
/// [builder] of a [BlocProvider], preventing the builder function from being 
/// invoked. This eliminates the need to mock the dependencies of the bloc
/// when running widget tests, since the the real bloc will never be built. 
@visibleForTesting 
void overrideBloc(Type blocType, BaseBloc override) {
  _blocOverrides[blocType] = override;
}

/// Reset the overrides after a test has completed to restore normal behaviour of 
/// BlocProvider. 
@visibleForTesting 
void resetBlocOverrides() {
  _blocOverrides.clear();
}

final _blocOverrides = Map<Type, BaseBloc>();