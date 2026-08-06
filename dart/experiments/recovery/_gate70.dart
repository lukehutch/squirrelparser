// _gate70.dart -- WHICH gate does the 30-second cap actually kill?
//
// `final_table.dart` measures an engine as one indivisible unit, so an engine
// that overruns reports `TO` in every column and says nothing about why. Twenty
// one of eighty two rows now read `TO`, and for several of them -- m51, m52,
// m53, m57, m58 -- the row recorded in LESSONS 5j is FAST (battms 372-1173,
// latms 313-632). Either those rows are stale or something else is expensive,
// and guessing between the two is not a measurement.
//
// So run each gate on its own, each in its own isolate, each under its own cap,
// and print the time. The gate bodies are the ones in `measureOne`, in its
// order; only the timing and the isolation are new.
//
//   dart ... _gate70.dart m53,m57,dot
import 'dart:async';
import 'dart:isolate';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart';

const gates = ['lat', 'batt', 'valid', 'truth', 'pred', 'depthLR', 'depthRR'];

/// One gate of one engine. Returns the wall time in ms, or throws.
double runGate(String name, String gate) {
  final (rules, battery, origShape, validDocs, latCases, depthLR, depthRR,
      depthLimit) = buildSetup();
  final engine = engines.firstWhere((e) => e.name == name);
  final sw = Stopwatch()..start();

  switch (gate) {
    case 'lat':
      // The untimed warm pass plus the five timed ones, as measureOne does.
      final (_, _, latCost) = engine.make(rules, 'JSON');
      for (var i = 0; i < 6; i++) {
        for (final m in latCases) {
          try {
            latCost(m);
          } catch (_) {}
        }
      }
    case 'batt':
      final (rec, cost, _) = engine.make(rules, 'JSON');
      for (final m in battery) {
        try {
          final r = rec(m);
          cost();
          covers(r.root, m.length);
          treeShape(r.root);
        } catch (_) {}
      }
    case 'valid':
      final (rec2, cost2, _) = engine.make(rules, 'JSON');
      for (final d in validDocs) {
        try {
          final r = rec2(d);
          cost2();
          r.errorSpans.isEmpty;
        } catch (_) {}
      }
    case 'truth':
      for (final (g, top, alpha, inputs) in truthCases) {
        final gr = MetaGrammar.parseGrammar(g);
        final (r3, _, c3) = engine.make(gr, top);
        for (final s in inputs) {
          truth(gr, top, g, s, alpha, 3);
          try {
            c3(s);
          } catch (_) {}
          try {
            covers(r3(s).root, s.length);
          } catch (_) {}
        }
      }
    case 'pred':
      for (final (g, top, alpha, inputs) in predCases) {
        final gr = MetaGrammar.parseGrammar(g);
        final (_, _, c4) = engine.make(gr, top);
        for (final s in inputs) {
          truth(gr, top, g, s, alpha, predMaxK);
          try {
            c4(s);
          } catch (_) {}
        }
      }
    case 'depthLR':
      // The SAME ladder measureOne uses. An earlier version of this probe used
      // [512..4096] and reported >90s for m62, an engine that completes its
      // whole measurement in under 30s -- `oneErr(k)` builds an input of about
      // 2k characters and the cost is superlinear, so one rung too far is not
      // a small error.
      depthLimit(engine, depthLR, const [256, 512, 1024, 2048]);
    case 'depthRR':
      depthLimit(engine, depthRR, const [256, 512, 1024, 2048]);
  }
  sw.stop();
  return sw.elapsedMicroseconds / 1000;
}

void gateIso(List<Object> msg) {
  final port = msg[0] as SendPort;
  try {
    port.send(<Object>['OK', runGate(msg[1] as String, msg[2] as String)]);
  } catch (e) {
    port.send(<Object>['ERR', '$e']);
  }
}

Future<String> capped(String name, String gate, Duration cap) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(
      gateIso, <Object>[rp.sendPort, name, gate],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(cap);
    if (v is List && v.isNotEmpty && v.first == 'OK') {
      return (v[1] as double).toStringAsFixed(0);
    }
    if (v is List && v.isNotEmpty && v.first == 'ERR') {
      final m = '${v[1]}';
      return m.contains('Stack Overflow') || m.contains('StackOverflow')
          ? 'SO'
          : 'ERR';
    }
    return 'DIED';
  } on TimeoutException {
    return '>${cap.inSeconds}s';
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

Future<void> main(List<String> args) async {
  // A generous cap, because the point is to see how far over 30s a gate goes,
  // not to reproduce the kill.
  final cap = Duration(seconds: int.parse(args.length > 1 ? args[1] : '180'));
  final names = args.isEmpty ? [for (final e in engines) e.name] : args[0].split(',');

  print('gate times in ms, each gate in its own isolate, cap ${cap.inSeconds}s');
  print('engine  ${[for (final g in gates) g.padLeft(8)].join()}      total');
  for (final n in names) {
    final cells = <String>[];
    var total = 0.0;
    var capped_ = false;
    for (final g in gates) {
      final c = await capped(n, g, cap);
      cells.add(c);
      final v = double.tryParse(c);
      if (v == null) {
        capped_ = true;
      } else {
        total += v;
      }
    }
    print('${n.padRight(7)} ${[for (final c in cells) c.padLeft(8)].join()}  '
        '${capped_ ? '>' : ' '}${total.toStringAsFixed(0).padLeft(9)}');
  }
}
