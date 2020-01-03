import 'dart:io';
import 'dart:collection';
import 'package:pint/src/util.dart';

class IntCode {
  var input = Queue<BigInt>(), output = Queue<BigInt>();
  Map d;
  var pc = B0, rel = B0;

  IntCode(List<BigInt> prog)
      : d = DefaultValueMapWrapper<BigInt,BigInt>(
            {for (int i = 0; i < prog.length; ++i) BigInt.from(i): prog[i]},
            B0);

  IntCode.fromFile(String filename) {
    var prog = File(filename)
        .readAsLinesSync()[0]
        .split(',')
        .map(BigInt.parse)
        .toList();
    d = DefaultValueMapWrapper(
        {for (int i = 0; i < prog.length; ++i) BigInt.from(i): prog[i]}, B0);
  }

  IntCode.fromStdin() {
    var prog = stdin.readLineSync().split(',').map(BigInt.parse).toList();
    d = DefaultValueMapWrapper(
        {for (int i = 0; i < prog.length; ++i) BigInt.from(i): prog[i]}, B0);
  }

  String disasseble(int op, BigInt a1, BigInt a2, BigInt a3) {
    switch (op) {
      case 1:
        return 'd[$a3] = d[$a1] + d[$a2] = ${d[a1]} + ${d[a2]} = ${d[a1] + d[a2]};';
      case 2:
        return 'd[$a3] = d[$a1] * d[$a2] = ${d[a1]} * ${d[a2]} = ${d[a1] * d[a2]};';
      case 3:
        return 'd[$a1] = input();';
      case 4:
        return 'output(d[$a1]) = output(${d[a1]});';
      case 5:
        return 'if d[$a1] = ${d[a1]} != 0: goto d[$a2] = ${d[a2]};';
      case 6:
        return 'if d[$a1] = ${d[a1]} == 0: goto d[$a2] = ${d[a2]};';
      case 7:
        return 'd[$a3] = d[$a1] < d[$a2]  <=>  ${d[a1]} < ${d[a2]}  <=>  ${d[a1]<d[a2] ? 1 : 0}';
      case 8:
        return 'd[$a3] = d[$a1] == d[$a2]  <=>  ${d[a1]} == ${d[a2]}  <=>  ${d[a1] == d[a2] ? 1 : 0}';
      case 9:
        return 'rel += d[$a1] = ${d[a1]}  =>  rel = ${rel + d[a1]}';
      case 99:
        return 'exit()';
      default:
        return 'UNKNOWN OP: $op';
    }
  }

  bool run([bool verbose = false, bool printmemory = false]) {
    while (true) {
      if (printmemory) {
        stdout.writeln();
        var hi = d.keys.whereType<BigInt>().fold(B0, (a,b)=> a > b ? a : b);
        var base = B0;
        while (base <= hi) {
          stdout.write('  $base:');
          for (var i = B0 ; i < B(5) ; i += B1) {
            stdout.write('\t${d[base+i]}');
          }
          stdout.writeln();
          base += B(5);
        }
        stdout.writeln();
      }
      var op = d[pc].toInt();
      BigInt a1, a2, a3;
      if (op >= 20000) {
        op -= 20000;
        a3 = rel + d[pc + B3];
      } else if (op >= 10000) {
        op -= 10000;
        a3 = pc + B3;
      } else {
        a3 = d[pc + B3];
      }
      if (op >= 2000) {
        op -= 2000;
        a2 = rel + d[pc + B2];
      } else if (op >= 1000) {
        op -= 1000;
        a2 = pc + B2;
      } else {
        a2 = d[pc + B2];
      }
      if (op >= 200) {
        op -= 200;
        a1 = rel + d[pc + B1];
      } else if (op >= 100) {
        op -= 100;
        a1 = pc + B1;
      } else {
        a1 = d[pc + B1];
      }
      if (verbose) {
        stdout.writeln('$pc: ${disasseble(op, a1, a2, a3)}');
      }
      switch (op) {
        case 1:
          d[a3] = d[a1] + d[a2];
          pc += B4;
          break;
        case 2:
          d[a3] = d[a1] * d[a2];
          pc += B4;
          break;
        case 3:
          if (input.isEmpty) return true;
          d[a1] = input.removeFirst();
          pc += B2;
          break;
        case 4:
          output.add(d[a1]);
          pc += B2;
          break;
        case 5:
          pc = d[a1] != B0 ? d[a2] : pc + B3;
          break;
        case 6:
          pc = d[a1] == B0 ? d[a2] : pc + B3;
          break;
        case 7:
          d[a3] = d[a1] < d[a2] ? B1 : B0;
          pc += B4;
          break;
        case 8:
          d[a3] = d[a1] == d[a2] ? B1 : B0;
          pc += B4;
          break;
        case 9:
          rel += d[a1];
          pc += B2;
          break;
        case 99:
          return false;
        default:
          throw 'Unknown op-code: ${op} at $pc';
      }
    }
  }
}
