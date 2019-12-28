import 'dart:io';
import 'package:pint/src/util.dart';
import 'package:pint/intcode_vm.dart';

void main(List<String> args) async {
  var prog = IntCode.fromFile(args[0]);
  var verbose = args.length > 1 && args[1] == '-v';
  var waiting = prog.run(verbose, verbose);
  while (prog.output.isNotEmpty) {
    stdout.writeln(prog.output.removeFirst());
  }
  if (!waiting) return;
  await for (var line in stdin.lines) {
    var data = BigInt.tryParse(line);
    if (data == null) {
      stderr.writeln('Cannot parse: $line');
    } else {
      prog.input.add(data);
      var waiting = prog.run(verbose, verbose);
      while (prog.output.isNotEmpty) {
        stdout.writeln(prog.output.removeFirst());
      }
      if (!waiting) break;
    }
  }
}
