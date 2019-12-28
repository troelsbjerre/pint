import 'dart:io';
import 'package:test/test.dart';
import 'package:pint/pint.dart';
import 'package:pint/intcode_vm.dart';
import 'package:pint/src/util.dart';

List<BigInt> runIntCodeFromFile(String filename, List<BigInt> input) {
  var vm = IntCode(parsePintFile(File(filename)).toIntCode());
  vm.input.addAll(input);
  expect(vm.run(), isFalse);
  return vm.output.toList();
}

void main() {
  test('compile empty', () {
    var intcode = parsePintLines([]).toIntCode();
    expect(intcode, [B(99)]);
  });
  test('add.pint', () {
    var range = B(10);
    for (var a = -range; a <= range; a += BigInt.one) {
      for (var b = -range; b <= range; b += BigInt.one) {
        expect(runIntCodeFromFile('examples/add.pint', [a,b]), [a+b]);
      }
    }
  });
  test('div.pint', () {
    expect(runIntCodeFromFile('examples/div.pint', [B(13),B(5)]), [B(2),B(3)]);
    expect(runIntCodeFromFile('examples/div.pint', [B(-13),B(5)]), [B(-2),B(-3)]);
    expect(runIntCodeFromFile('examples/div.pint', [B(13),B(-5)]), [B(-2),B(3)]);
    expect(runIntCodeFromFile('examples/div.pint', [B(-13),B(-5)]), [B(2),B(-3)]);
    expect(runIntCodeFromFile('examples/div.pint', [B(-23),B(7)]), [B(-3),B(-2)]);
  });
  test('range.pint', () {
    expect(runIntCodeFromFile('examples/range.pint', [B(3), B(9), B(2)]), [B(3), B(5), B(7)]);
    expect(runIntCodeFromFile('examples/range.pint', [B(2), B(9), B(3)]), [B(2), B(5), B(8)]);
  });
  test('swap.pint', () {
    expect(runIntCodeFromFile('examples/swap.pint', [B(1), B(2)]), [B(2), B(1)]);
  });
  test('binom.pint', () {
    expect(runIntCodeFromFile('examples/binom.pint', [B(10), B(5)]), [B(252)]);
  });
}
