import 'dart:io';
import 'package:pint/src/util.dart';
import 'package:pint/intcode_vm.dart';

void main(List<String> args) async {
  var verbose = false;
  var printmem = false;
  var ascii = false;
  String filename;
  for (var arg in args) {
    if (arg[0] == '-') {
      for (var i = 1; i < arg.length; ++i) {
        switch (arg[i]) {
          case 'v':
            verbose = true;
            break;
          case 'm':
            printmem = true;
            break;
          case 'a':
            ascii = true;
            break;
        }
      }
    } else {
      if (filename == null) {
        filename = arg;
      } else {
        print('Cannot run two programs');
        return;
      }
    }
  }
  var prog = IntCode.fromFile(filename);
  var waiting = prog.run(verbose, printmem);
  if (ascii) {
    stdout.write(
        String.fromCharCodes(prog.output.map((bigint) => bigint.toInt())));
    prog.output.clear();
    if (!waiting) return;
    await for (var data in stdin) {
      prog.input.addAll(data.map((i) => BigInt.from(i)));
      var waiting = prog.run(verbose, verbose);
      stdout.write(
          String.fromCharCodes(prog.output.map((bigint) => bigint.toInt())));
      prog.output.clear();
      if (!waiting) break;
    }
  } else {
    stdout.writeln(prog.output.join('\n'));
    prog.output.clear();
    if (!waiting) return;
    await for (var line in stdin.lines) {
      var data = BigInt.tryParse(line);
      if (data == null) {
        stderr.writeln('Cannot parse: $line');
      } else {
        prog.input.add(data);
        stdout.writeln(prog.output.join('\n'));
        prog.output.clear();
        if (!waiting) break;
      }
    }
  }
}
