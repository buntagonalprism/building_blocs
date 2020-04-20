import 'dart:async';

import 'package:building_blocs/building_blocs.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  List<String> captured1;
  List<String> captured2;

  setUp(() {
    captured1 = <String>[];
    captured2 = <String>[];
  });



  group('From broadcast streams', () {
    StreamController<String> controller;
    setUp(() {
      controller = StreamController<String>.broadcast();
    });

    group('Stream property', () {

      test('Is a broadcast stream', () {
        final vs = DataStream.of(controller.stream);
        expect(vs.stream.isBroadcast, true);
      });

      test('Passes listen and cancel to source stream', () {
        bool listen = false;
        bool cancel = false;
        final c = StreamController<String>.broadcast(
          onListen: () => listen = true,
          onCancel: () => cancel = true,
        );
        final vs = DataStream.of(c.stream);
        expect([listen, cancel], [false, false]);
        final sub = vs.stream.listen((data) => captured1.add(data));
        expect([listen, cancel], [true, false]);
        sub.cancel();
        expect([listen, cancel], [true, true]);
      });
    });


    group('Without keepAlive', () {

      test('Drops events added before any listener attached', () async {
        final vs = DataStream.of(controller.stream);
        controller.add('dropped-a');
        controller.add('dropped-bb');
        await pump();
        expect(vs.value, null);
      });

      test('Values added with no listeners does not set hasAddedValue', () async {
        final vs = DataStream.of(controller.stream);
        controller.add('dropped');
        await pump();
        expect(vs.hasAddedValue, isFalse);
      });

      test('Emits values to current listeners and contains emitted value', () async {
        final vs = DataStream.of(controller.stream);
        controller.add('dropped');
        await pump();
        vs.runAndListen((data) => captured1.add(data));
        controller.add('listened');
        await pump();
        expect(captured1, ['listened']);
        expect(vs.value, 'listened');
      });

      test('Sets hasAddedValue when emitting to listeners', () async {
        final vs = DataStream.of(controller.stream);
        await pump();
        vs.runAndListen((data) => captured1.add(data));
        controller.add('listened');
        await pump();
        expect(vs.hasAddedValue, isTrue);
      });

      test('Drops events between listeners, and maintains last emitted value', () async {
        final vs = DataStream.of(controller.stream);
        final sub = vs.runAndListen((_){});
        controller.add('listened-to');
        await pump();
        await sub.cancel();
        controller.add('dropped-1');
        controller.add('dropped-2');
        await pump();
        vs.runAndListen((data) => captured1.add(data));
        await pump();
        expect(vs.value, 'listened-to');
        expect(captured1, ['listened-to']);
      });
    });

    group('With keepAlive', () {
      test('Contains last value added before first listener', () async {
        final vs = DataStream.of(controller.stream, keepAlive: true);
        controller.add('a');
        controller.add('b');
        await pump();
        expect(vs.value, 'b');
      });

      test('Values added without listeners set hasAddedValue', () async {
        final vs = DataStream.of(controller.stream, keepAlive: true);
        controller.add('a');
        await pump();
        expect(vs.hasAddedValue, isTrue);
      });

      test('Values added with listeners also sets hasAddedValue', () async {
        final vs = DataStream.of(controller.stream, keepAlive: true);
        vs.runAndListen((data) => captured1.add(data));
        controller.add('a');
        await pump();
        expect(vs.hasAddedValue, isTrue);
      });

      test('Emits values to current listeners and contains emitted value', () async {
        final vs = DataStream.of(controller.stream);
        vs.runAndListen((data) => captured1.add(data));
        controller.add('emitted');
        await pump();
        expect(captured1, ['emitted']);
        expect(vs.value, 'emitted');
      });

      test('Contains last value added between listeners', () async {
        final vs = DataStream.of(controller.stream, keepAlive: true);
        final sub = vs.runAndListen((_){});
        controller.add('h');
        await pump();
        await sub.cancel();
        controller.add('j');
        controller.add('k');
        await pump();
        vs.runAndListen((data) => captured1.add(data));
        await pump();
        expect(vs.value, 'k');
      });

      test('Dispose cancels inner subscription when there are no current listeners', () async {
        bool cancelled = false;
        final controller = StreamController<String>.broadcast(
          onCancel: () => cancelled = true,
        );
        final vs = DataStream.of(controller.stream, keepAlive: true);
        expect(cancelled, isFalse);
        await vs.dispose();
        expect(cancelled, isTrue);
      });

      test('Dispose cancels inner subscription even if there are current listeners', () async {
        bool cancelled = false;
        final controller = StreamController<String>.broadcast(
          onCancel: () => cancelled = true,
        );
        final vs = DataStream.of(controller.stream, keepAlive: true);
        vs.runAndListen((data) => captured1.add(data));
        vs.runAndListen((data) => captured2.add(data));
        expect(cancelled, isFalse);
        await vs.dispose();
        expect(cancelled, isTrue);
      });

    });



    group('Seeded value', () {
      test('Seed value available immediately', () {
        final vs = DataStream.seeded(controller.stream, seed: 'jkl');
        expect(vs.value, 'jkl');
      });

      test('Seed with null sets hasAddedValue', () {
        final vs = DataStream.seeded(controller.stream, seed: null);
        expect(vs.hasAddedValue, isTrue);
      });

      test('Sets with data sets hasAddedValue', () {
        final vs = DataStream.seeded(controller.stream, seed: 'abc');
        expect(vs.hasAddedValue, isTrue);
      });

      test('Respects keep alive, updating its value even when there are no listeners', () async {
        final vs = DataStream.seeded(controller.stream, seed: 'seed', keepAlive: true);
        controller.add('added');
        await pump();
        expect(vs.value, 'added');
      });
    });

    group('Run and listen', () {

      bool listen;
      StreamController<String> c;
      setUp(() {
        c = StreamController<String>.broadcast(onListen: () => listen = true);
      });

      test('Subscribes to the inner stream', () async {
        final vs = DataStream.of(c.stream);
        vs.runAndListen((data) => captured1.add(data));
        expect(listen, isTrue);
      });
      test('Runs with existing stream null value if added', () async {
        final vs = DataStream<String>.seeded(c.stream, seed: null);
        vs.runAndListen((data) => captured1.add(data));
        expect(vs.hasAddedValue, isTrue);
        expect(captured1, [null]);
      });
      test('Runs with existing stream non-null value', () async {
        final vs = DataStream<String>.seeded(c.stream, seed: 'q');
        vs.runAndListen((data) => captured1.add(data));
        expect(vs.hasAddedValue, isTrue);
        expect(captured1, ['q']);
      });
      test('Runs with existing value rather than provided seed value', () {
        final vs = DataStream<String>.seeded(c.stream, seed: 'existing');
        vs.runAndListen((data) => captured1.add(data), seed: 'seed');
        expect(captured1, ['existing']);
      });
      test('Runs with seed value only if stream does not have a value', () {
        final vs = DataStream<String>.of(c.stream);
        expect(vs.hasAddedValue, isFalse);
        vs.runAndListen((data) => captured1.add(data), seed: 'seed');
        expect(captured1, ['seed']);
      });
      test('Does not run if no added value and no seed', () {
        final vs = DataStream<String>.of(c.stream);
        bool didRun = false;
        vs.runAndListen((_) => didRun = true);
        expect(didRun, isFalse);
      });
    });

    group('Map stream', () {

      StreamController<String> c;
      setUp(() {
        c = StreamController<String>.broadcast();
      });

      test('Converts initial value', () {
        final vs = DataStream.seeded(c.stream, seed: 'a');
        final map = vs.map((String data) => '$data-$data');
        expect(map.value, 'a-a');
      });

      test('Emits converted values', () async {
        final vs = DataStream.seeded(c.stream, seed: 'a');
        final map = vs.map((String data) => '$data-$data');
        map.stream.listen((String data) => captured1.add(data));
        c.add('b');
        await pump();
        expect(captured1, ['b-b']);
        expect(map.value, 'b-b');
      });

      test('On next listen emits conveted if source value changed', () async {
        final vs = DataStream.seeded(c.stream, seed: 'a');
        final map = vs.map((String data) => '$data-$data');
        vs.stream.listen((_){});
        c.add('b');
        await pump();
        expect(vs.value, 'b');
        expect(map.value, 'a-a');
        map.stream.listen((String data) => captured1.add(data));
        await pump();
        expect(captured1, ['b-b']);
      });

      test('On next listen does not emit if source value unchanged', () async {
        final vs = DataStream.seeded(c.stream, seed: 'a');
        final map = vs.map((String data) => '$data-$data');
        vs.stream.listen((_){});
        c.add('b');
        await pump();
        expect(vs.value, 'b');

        // Change it back
        c.add('a');
        await pump();
        expect(vs.value, 'a');
        expect(map.value, 'a-a');

        // Listen to combined stream
        map.stream.listen((String data) => captured1.add(data));
        await pump();
        expect(captured1, isEmpty);
      });
    });

    group('Error handling', () {
      final error = 'oh-no';
      final trace = StackTrace.fromString('oops');
      StreamController<String> c;
      setUp(() {
        c = StreamController<String>.broadcast();
      });

      test('Errors in source stream dropped while there are no listeners', () {
        final vs = DataStream.of(c.stream);
        c.addError(error, trace);
        expect(vs.error, isNull);
      });

      test('Error in source stream emits error trace event to listeners', () async {
        final vs = DataStream.of(c.stream);
        bool didError;
        vs.stream.listen((data) => captured1.add(data), onError: (e, t) {
          didError = true;
          expect(e is ErrorTrace, isTrue);
          expect((e as ErrorTrace).error, error);
          expect((e as ErrorTrace).trace, trace);
          expect(t, trace);
        });
        c.addError(error, trace);
        await pump();
        expect(didError, true);
      });

      test('Error in source stream sets error property', () async {
        final vs = DataStream.of(c.stream);
        vs.stream.listen((data) => captured1.add(data), onError: (_, __) {});
        c.addError(error, trace);
        await pump();
        expect(vs.error, isNotNull);
        expect(vs.error.error, error);
        expect(vs.error.trace, trace);
      });

      test('Error in source stream does not clear value', () async {
        final vs = DataStream.seeded(c.stream, seed: 'value');
        vs.stream.listen((data) => captured1.add(data), onError: (_, __) {});
        c.addError(error, trace);
        await pump();
        expect(vs.error, isNotNull);
        expect(vs.value, 'value');
        expect(vs.hasAddedValue, isTrue);
      });

      test('New value clears error', () async {
        final vs = DataStream.seeded(c.stream, seed: 'value');
        vs.stream.listen((data) => captured1.add(data), onError: (_, __) {});
        c.addError(error, trace);
        await pump();
        expect(vs.error, isNotNull);
        c.add('horray');
        await pump();
        expect(vs.error, isNull);
        expect(vs.value, 'horray');
      });
    });

    /// Test added in response to an observed defect. The defect was that
    /// cancelling a subscription on a value stream then immediately listening
    /// again did not re-listen to the source stream.
    test('Can be immediately resubscribed to', () {
      int listen = 0;
      int cancel = 0;
      final c = StreamController<String>.broadcast(
        onListen: () => listen++,
        onCancel: () => cancel++,
      );
      final vs = DataStream.of(c.stream);
      final sub = vs.runAndListen((_){});
      sub.cancel();
      vs.runAndListen((_){});
      expect(listen, 2);
      expect(cancel, 1);
    });
  });


  group('From combining streams', () {


    String concat(String a, String b, String c) => '$a-$b-$c';

    test('May be listened to multiple times and emits to all listeners', () async {
      final vs1 = DataStreamController.seeded(seed: 'a');
      final vs2 = DataStreamController.seeded(seed: 'b');
      final vs3 = DataStreamController.seeded(seed: 'c');

      final c = DataStream.combineLatest3(vs1, vs2, vs3, concat);
      c.runAndListen((data) => captured1.add(data));
      c.runAndListen((data) => captured2.add(data));

      await pump();
      expect(captured1, ['a-b-c']);
      expect(captured2, ['a-b-c']);
    });

    group('Without keep alive', () {

      test('Waits for a listener before connecting to source streams', () async {
        int listened = 0;
        final c1 = StreamController<String>.broadcast(onListen: () => listened++);
        final c2 = StreamController<String>.broadcast(onListen: () => listened++);
        final c3 = StreamController<String>.broadcast(onListen: () => listened++);

        final combined = DataStream.combineLatest3(
          DataStream.of(c1.stream),
          DataStream.of(c2.stream),
          DataStream.of(c3.stream),
          concat,
        );

        expect(listened, 0);
        combined.runAndListen((data) => captured1.add(data));
        expect(listened, 3);
      });

      test('Unsubscribes from source streams when last listener detaches', () async {
        int cancelled = 0;
        final c1 = StreamController<String>.broadcast(onCancel: () => cancelled++);
        final c2 = StreamController<String>.broadcast(onCancel: () => cancelled++);
        final c3 = StreamController<String>.broadcast(onCancel: () => cancelled++);

        final combined = DataStream.combineLatest3(
          DataStream.of(c1.stream),
          DataStream.of(c2.stream),
          DataStream.of(c3.stream),
          concat,
        );

        expect(cancelled, 0);
        final subscription1 = combined.runAndListen((data) => captured1.add(data));
        final subscription2 = combined.runAndListen((data) => captured2.add(data));
        await subscription1.cancel();
        expect(cancelled, 0);
        await subscription2.cancel();
        expect(cancelled, 3);
      });
    });

    group('With keep alive', () {
      test('Connects to all source streams immediately', () async {
        int listened = 0;
        final c1 = StreamController<String>.broadcast(onListen: () => listened++);
        final c2 = StreamController<String>.broadcast(onListen: () => listened++);
        final c3 = StreamController<String>.broadcast(onListen: () => listened++);

        DataStream.combineLatest3(
          DataStream.of(c1.stream),
          DataStream.of(c2.stream),
          DataStream.of(c3.stream),
          concat,
          keepAlive: true,
        );
        expect(listened, 3);
      });

      test('Dispose disconnects from all source streams when there are no current listeners', () async {
        int cancelled = 0;
        final c1 = StreamController<String>.broadcast(onCancel: () => cancelled++);
        final c2 = StreamController<String>.broadcast(onCancel: () => cancelled++);
        final c3 = StreamController<String>.broadcast(onCancel: () => cancelled++);

        final combined = DataStream.combineLatest3(
          DataStream.of(c1.stream),
          DataStream.of(c2.stream),
          DataStream.of(c3.stream),
          concat,
          keepAlive: true,
        );

        expect(cancelled, 0);
        await combined.dispose();
        expect(cancelled, 3);
      });

      test('Dispose disconnects from all source streams even if there are current listeners', () async {
        int cancelled = 0;
        final c1 = StreamController<String>.broadcast(onCancel: () => cancelled++);
        final c2 = StreamController<String>.broadcast(onCancel: () => cancelled++);
        final c3 = StreamController<String>.broadcast(onCancel: () => cancelled++);

        final combined = DataStream.combineLatest3(
          DataStream.of(c1.stream),
          DataStream.of(c2.stream),
          DataStream.of(c3.stream),
          concat,
          keepAlive: true,
        );
        expect(cancelled, 0);
        combined.runAndListen((data) => captured1.add(data));
        combined.runAndListen((data) => captured2.add(data));
        await combined.dispose();
        expect(cancelled, 3);
      });


    });


    group('Value combining', () {

      StreamController<String> c1;
      StreamController<String> c2;
      StreamController<String> c3;
      setUp(() {
        c1 = StreamController<String>.broadcast();
        c2 = StreamController<String>.broadcast();
        c3 = StreamController<String>.broadcast();
      });

      group('If all streams have added values initially', () {

        test('Updates the combined value immediately', () {
          final combined = DataStream.combineLatest3(
            DataStream.seeded(c1.stream, seed: 'a'),
            DataStream.seeded(c2.stream, seed: 'b'),
            DataStream.seeded(c3.stream, seed: 'c'),
            concat,
          );
          expect(combined.value, 'a-b-c');
          expect(combined.hasAddedValue, isTrue);
        });

        test('A new combined value is output for every source output', () async {
          final combined = DataStream.combineLatest3(
            DataStream.seeded(c1.stream, seed: 'a'),
            DataStream.seeded(c2.stream, seed: 'b'),
            DataStream.seeded(c3.stream, seed: 'c'),
            concat,
          );
          combined.stream.listen((data) => captured1.add(data));
          c1.add('d');
          await pump();
          expect(captured1, ['d-b-c']);
          expect(combined.value, 'd-b-c');
          c3.add('f');
          await pump();
          expect(captured1, ['d-b-c', 'd-b-f']);
          expect(combined.value, 'd-b-f');
        });
      });

      group('If some streams do not have added values', () {
        test('Waits for remaining streams to output before outputting combining values', () async {
          final combined = DataStream.combineLatest3(
            DataStream.seeded(c1.stream, seed: 'seeded_on_1'),
            DataStream.of(c2.stream),
            DataStream.of(c3.stream),
            concat,
          );
          expect(combined.value, isNull);
          expect(combined.hasAddedValue, isFalse);
          combined.runAndListen((data) => captured1.add(data));

          c2.add('added_to_2');
          await pump();
          expect(captured1, isEmpty);

          c3.add('added_to_3');
          await pump();
          expect(captured1, ['seeded_on_1-added_to_2-added_to_3']);
        });

        test('First combined output has latest value from streams with initial values', () async {
          final combined = DataStream.combineLatest3(
            DataStream.seeded(c1.stream, seed: 'seeded_on_1'),
            DataStream.of(c2.stream),
            DataStream.of(c3.stream),
            concat,
          );
          combined.runAndListen((data) => captured1.add(data));

          c1.add('latest_on_1');
          await pump();
          expect(captured1, isEmpty);

          c2.add('added_to_2');
          c3.add('added_to_3');
          await pump();
          final emitted = 'latest_on_1-added_to_2-added_to_3';
          expect(captured1, [emitted]);
          expect(combined.hasAddedValue, isTrue);
          expect(combined.value, emitted);
        });

        test('After first combined output, each source output emits a combined output', () async {
          final combined = DataStream.combineLatest3(
            DataStream.seeded(c1.stream, seed: 'cake'),
            DataStream.of(c2.stream),
            DataStream.of(c3.stream),
            concat,
          );
          combined.runAndListen((data) => captured1.add(data));

          c2.add('fix');
          c3.add('equal');
          await pump();
          expect(captured1, ['cake-fix-equal']);

          c1.add('sad');
          await pump();
          expect(captured1.last, 'sad-fix-equal');
          expect(combined.value, 'sad-fix-equal');

          c3.add('king');
          await pump();
          expect(captured1.last, 'sad-fix-king');
          expect(combined.value, 'sad-fix-king');
        });
      });

      group('On stream listen', () {

        int combinedCount;
        String Function(String a, String b, String c) combiner;
        setUp(() {
          combinedCount = 0;
          combiner = (a, b, c) {
            combinedCount++;
            return '$a-$b-$c';
          };
        });

        test('Does not run combiner if any stream does not have a value', () async {
          final combined = DataStream.combineLatest3(
            DataStream.seeded(c1.stream, seed: 'port'),
            DataStream.seeded(c2.stream, seed: 'phone'),
            DataStream.of(c3.stream),
            combiner,
          );
          expect(combinedCount, 0);
          combined.stream.listen((data) => captured1.add(data));
          await pump();
          expect(combinedCount, 0);
        });

        test('Does not emit latest combined value if all source values unchanged', () async {
          final vs1 = DataStream.seeded(c1.stream, seed: 'seed');
          final combined = DataStream.combineLatest3(
            vs1,
            DataStream.seeded(c2.stream, seed: 'white'),
            DataStream.seeded(c3.stream, seed: 'car'),
            combiner,
          );
          expect(combinedCount, 1);
          expect(combined.value, 'seed-white-car');

          // Listen to this stream so its value updates
          vs1.stream.listen((data) => captured1.add(data));
          await pump();
          c1.add('other');
          await pump();
          expect(vs1.value, 'other');

          // Return to previous state so combiner shouldn't run again with same data
          c1.add('seed');
          await pump();
          combined.stream.listen((data) => captured2.add(data));
          await pump();
          expect(combinedCount, 1);
          expect(captured2, isEmpty);
        });

        test('Emits latest combined value if any source has a new value', () async {

          final vs1 = DataStream.seeded(c1.stream, seed: 'seed');
          final combined = DataStream.combineLatest3(
            vs1,
            DataStream.seeded(c2.stream, seed: 'white'),
            DataStream.seeded(c3.stream, seed: 'car'),
            combiner,
          );
          expect(combinedCount, 1);
          expect(combined.value, 'seed-white-car');

          // Listen to this stream so its value updates
          vs1.stream.listen((data) => captured1.add(data));
          await pump();
          c1.add('other');
          await pump();

          // On listen runs the combiner on latest values and emits
          expect(combined.value, 'seed-white-car');
          combined.stream.listen((data) => captured2.add(data));
          await pump();
          expect(combinedCount, 2);
          expect(combined.value, 'other-white-car');
          expect(captured2, [combined.value]);
        });

        test('Emits any source error if different to combined error', () async {

          final vs1 = DataStream.seeded(c1.stream, seed: 'seed');
          final combined = DataStream.combineLatest3(
            vs1,
            DataStream.seeded(c2.stream, seed: 'white'),
            DataStream.seeded(c3.stream, seed: 'car'),
            combiner,
          );
          expect(combinedCount, 1);
          expect(combined.value, 'seed-white-car');

          // Any source error results in a combined error
          final sub = combined.stream.listen((_) {}, onError: (_){});
          c1.addError('FIRST-ERR');
          await pump();
          expect(combined.error.error, 'FIRST-ERR');

          // Ad an error to a source stream while combine stream is not listening
          await sub.cancel();
          vs1.stream.listen((_) {}, onError: (_) {});
          c1.addError('SECOND-ERR');
          await pump();
          expect(combined.error.error, 'FIRST-ERR');

          // On combined listen, outputs new error and no value
          final List<ErrorTrace> errors = <ErrorTrace>[];
          combined.stream.listen((data) => captured1.add(data), onError: (err) => errors.add(err));
          await pump();
          expect(combined.error.error, 'SECOND-ERR');
          expect(captured1, isEmpty);
          expect(errors[0].error, 'SECOND-ERR');

        });
      });

    });

  });

  group('Value Stream Builder', () {

    StreamController<String> c;
    setUp(() {
      c = StreamController<String>.broadcast();
    });

    testWidgets('Uses value for single-pass initial build', (WidgetTester tester) async {
      final vs = DataStream.seeded(c.stream, seed: 'hello');
      await tester.pumpWidget(DataStream.builder(stream: vs, builder: (c, s) {
        captured1.add(s.data);
        return Container();
      }));
      await tester.pumpAndSettle();
      expect(captured1, ['hello']);
    });

    testWidgets('Initial build with null value if no value provided', (WidgetTester tester) async {
      final vs = DataStream.of(c.stream);
      await tester.pumpWidget(DataStream.builder(stream: vs, builder: (c, s) {
        captured1.add(s.data);
        return Container();
      }));
      await tester.pumpAndSettle();
      expect(captured1, [null]);
    });

    testWidgets('Stream updates trigger rebuild with new value', (WidgetTester tester) async {
      final vs = DataStream.seeded(c.stream, seed: 'seed');
      await tester.pumpWidget(DataStream.builder(stream: vs, builder: (c, s) {
        captured1.add(s.data);
        return Container();
      }));
      await tester.pumpAndSettle();
      c.add('new');
      await doublePump(tester);
      expect(captured1, ['seed', 'new']);
    });

    // Create a stream with an error
    Future<DataStream> streamWithError(WidgetTester tester) async {
      final vs = DataStream.seeded(c.stream, seed: 'seed');
      vs.stream.listen((_){}, onError: (_) {});
      c.addError('ERR');
      await tester.pump();
      expect(vs.error, isNotNull);
      return vs;
    }

    testWidgets('If stream already has error, builds once with error only', (WidgetTester tester) async {
      final vs = await streamWithError(tester);

      // Building with this stream should display the error not the value
      final List<ErrorTrace> errors = <ErrorTrace>[];
      await tester.pumpWidget(DataStream.builder(stream: vs, builder: (c, s) {
        captured1.add(s.data);
        errors.add(s.error);
        return Container();
      }));
      await tester.pumpAndSettle();
      expect(captured1, [null]);
      expect(errors[0].error, 'ERR');
    });

    testWidgets('Adding a value after an error rebuilds with the new value', (WidgetTester tester) async {
      final vs = await streamWithError(tester);

      // Building with this stream should display the error not the value
      final List<ErrorTrace> errors = <ErrorTrace>[];
      await tester.pumpWidget(DataStream.builder(stream: vs, builder: (c, s) {
        captured1.add(s.data);
        errors.add(s.error);
        return Container();
      }));
      await tester.pumpAndSettle();
      c.add('success');
      await doublePump(tester);
      expect(captured1, [null, 'success']);
      expect(errors[1], null);
    });

    testWidgets('Changing stream builds with value of new stream', (WidgetTester tester) async {
      final rebuild = Completer<bool>();
      final vs1 = DataStreamController<String>.seeded(seed: 'first');
      final vs2 = DataStreamController<String>.seeded(seed: 'second');
      await tester.pumpWidget(FutureBuilder<bool>(
        future: rebuild.future,
        builder: (c, fs) {
          return DataStream.builder<String>(
            stream: fs.data == true? vs2 : vs1,
            builder: (c, s) {
              captured1.add(s.data);
              return Container();
            }
          );
        },
      ));
      expect(captured1, ['first']);
      rebuild.complete(true);
      await doublePump(tester);
      expect(captured1, ['first', 'second']);
    });

  });

}

/// Trigger the next microtask by waiting for a duration of 0. Should only be used in unit tests
/// run with [test()]. In widget tests run with [testWidgets()] use tester.pump() instead
Future pump() {
  return Future.delayed(Duration());
}

/// It takes two microtasks to rebuild when stream data changes - one for the stream builder to
/// receive the data and request a rebuild, the other for streambuilder to perform the rebuild.
Future doublePump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}