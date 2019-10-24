part of building_blocs;

/// Use this to get an instance of a bloc provider runtime type
/// when running flutter tests. 
Type blocProviderType<T extends BaseBloc>(T mockBloc) {	
  return BlocProvider(	
    blocBuilder: () => mockBloc,	
    child: Container(),	
  ).runtimeType;	
}