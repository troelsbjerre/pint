import 'dart:io';
import 'package:pint/pint.dart';

void main(List<String> args) {
  var srcFile = File(args[0]);
  var ast = parsePintLines(srcFile.readAsLinesSync());
  var dstFilename = args[1];
  if (dstFilename.endsWith('.int')) {
    File(dstFilename).openWrite().writeln(ast.toIntCode().join(','));
  } else if (dstFilename.endsWith('.py')) {
    File(dstFilename).openWrite().writeln(ast.toPython().join('\n'));
  }
}
