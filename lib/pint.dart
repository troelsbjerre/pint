import 'dart:io';
import 'package:pint/src/pint_ast.dart';

var indentRegExp = RegExp(r'^\s*');

Main parsePintFile(File input) => parsePintLines(input.readAsLinesSync());

Main parsePintLines(List<String> pintSourceLines) {
  var blocks = <Instruction>[];
  var indent = <Instruction, int>{};
  var mainblock = Main();
  indent[mainblock] = -1;
  blocks.add(mainblock);
  var linenum = 0;
  for (var line in pintSourceLines) {
    ++linenum;
    var indentMatch = indentRegExp.firstMatch(line);
    if (indentMatch.end == line.length) {
      continue;
    }
    Instruction ins;
    try {
      ins = Instruction.parse(line);
    } on String catch (e) {
      throw 'Line $linenum: $e\n$line';
    }
    indent[ins] = indentMatch.end;
    while (indent[ins] <= indent[blocks.last]) {
      blocks.removeLast();
    }
    if (!blocks.last.addChild(ins)) {
      throw ('Line $linenum: Unexpected indentation level:\n$line');
    }
    blocks.add(ins);
  }
  return mainblock;
}
