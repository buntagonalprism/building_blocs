import 'package:building_blocs/building_blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bloc provider supplies bloc to children',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: BlocProvider(
            blocBuilder: () => MyBloc(),
            child: Builder(
              builder: (ctx) {
                return Text(BlocProvider.of<MyBloc>(ctx).data.value);
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('Can find bloc provider widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: BlocProvider(
            blocBuilder: () => MyBloc(),
            child: Builder(
              builder: (ctx) {
                return Text(BlocProvider.of<MyBloc>(ctx).data.value);
              },
            ),
          ),
        ),
      ),
    );
  });
  expect(find.byType(blocProviderType(MyBloc())), findsOneWidget);
}

class MyBloc extends BaseBloc {
  DataStreamController<String> data;

  MyBloc() {
    data = newSeededDataStream(seedValue: 'hello');
  }
}
