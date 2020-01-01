import 'util.dart';
import 'dart:math';
import 'dart:convert';

BigInt tryParseBigIntOrChar(String input) {
  var bi = BigInt.tryParse(input);
  if (bi != null) return bi;
  if (input.length < 3 || input[0] != "'" || input[input.length - 1] != "'") return null;
  var js = jsonDecode('"${input.substring(1,input.length-1)}"').toString();
  if (js.length != 1) return null;
  return B(js.codeUnitAt(0));
}

abstract class Instruction {
  Instruction next, parent;
  int codeIndex;
  Instruction();

  Iterable<String> toPython([int indent = 0]);

  factory Instruction.parse(String line) {
    return Op.tryParse(line) ??
        Input.tryParse(line) ??
        Output.tryParse(line) ??
        Conditional.tryParse(line) ??
        Definition.tryParse(line) ??
        Call.tryParse(line) ??
        Return.tryParse(line) ??
        (throw 'Cannot parse:\n$line');
  }

  Iterable<String> get readVariables;
  Iterable<String> get writeVariables;

  bool addChild(Instruction child) => false;

  Iterable<Instruction> get descendants sync* {
    yield this;
  }

  List<BigInt> encode(Map<String, int> locals, Map<String, int> globals,
      Map<String, Definition> functions, int opnum);
}

abstract class Block extends Instruction {
  Instruction firstChild, lastChild;

  Iterable<Instruction> get children sync* {
    for (var child = firstChild ; child != null ; child = child.next) {
      yield child;
    }
  }

  @override
  bool addChild(Instruction child) {
    child.parent = this;
    if (firstChild == null) {
      firstChild = lastChild = child;
    } else {
      lastChild.next = child;
      lastChild = child;
    }
    return true;
  }

  @override
  Iterable<Instruction> get descendants sync* {
    yield this;
    for (var child in children) {
      yield* child.descendants;
    }
  }
}

var opRegExp = RegExp(
    r"^(?<indent> *)(?<target>[A-Za-z]+) (?<assign>=|\+=|-=|\*=) (?<left>'.*'|[A-Za-z]+|-?[0-9]+)( (?<op>[-+*]) (?<right>'.*'|[A-Za-z]+|-?[0-9]+))?$");

class Op extends Instruction {
  String target, left, right, op;

  Op(RegExpMatch match) {
    target = match.namedGroup('target');
    left = match.namedGroup('left');
    op = match.namedGroup('op');
    right = match.namedGroup('right');
    var assign = match.namedGroup('assign');
    if (assign.length == 2) {
      right = left;
      op = assign[0];
      left = target;
    }
    if (op == '-') {
      var rval = tryParseBigIntOrChar(right);
      if (rval == null) {
        throw 'Cannot subtract variable:\n${match.input}';
      }
      op = '+';
      right = '${-rval}';
    } else if (op == null) {
      op = '+';
      right = '0';
    }
  }

  factory Op.tryParse(String line) {
    var match = opRegExp.firstMatch(line);
    return match == null ? null : Op(match);
  }

  @override
  Iterable<String> get readVariables => [left, right];

  @override
  Iterable<String> get writeVariables => [target];

  @override
  Iterable<String> toPython([int indent = 0]) sync* {
    yield '${''.padLeft(indent)}$target = $left $op $right';
  }

  @override
  List<BigInt> encode(Map<String, int> locals, Map<String, int> globals,
      Map<String, Definition> functions, int opnum) {
    if (codeIndex == null) {
      codeIndex = opnum;
    } else {
      assert(codeIndex == opnum);
    }
    var code = [op == '+' ? B(1) : B(2), null, null, null];
    var val = tryParseBigIntOrChar(left);
    if (val != null) {
      code[1] = val;
      code[0] += B(100);
    } else {
      var offset = globals[left];
      if (offset != null) {
        code[1] = B(offset);
      } else {
        offset = locals[left];
        if (offset == null) locals[left] = offset = locals.length;
        code[1] = B(offset);
        code[0] += B(200);
      }
    }
    val = tryParseBigIntOrChar(right);
    if (val != null) {
      code[2] = val;
      code[0] += B(1000);
    } else {
      var offset = globals[right];
      if (offset != null) {
        code[2] = B(offset);
      } else {
        offset = locals[right];
        if (offset == null) locals[right] = offset = locals.length;
        code[2] = B(offset);
        code[0] += B(2000);
      }
    }
    var offset = globals[target];
    if (offset != null) {
      code[3] = B(offset);
    } else {
      offset = locals[target] ?? (locals[target] = locals.length);
      code[3] = B(offset);
      code[0] += B(20000);
    }
    return code;
  }
}

var inputRegExp =
    RegExp(r'^(?<indent> *)(?<target>[A-Za-z]+) *= *(input\(\)|int\(input\(\)\))$');

class Input extends Instruction {
  String target;

  Input(RegExpMatch match) {
    target = match.namedGroup('target');
  }

  factory Input.tryParse(String line) {
    var match = inputRegExp.firstMatch(line);
    return match == null ? null : Input(match);
  }

  @override
  Iterable<String> get readVariables => [];

  @override
  Iterable<String> get writeVariables => [target];

  @override
  Iterable<String> toPython([int indent = 0]) sync* {
    yield '${''.padLeft(indent)}$target = int(input())';
  }

  @override
  List<BigInt> encode(Map<String, int> locals, Map<String, int> globals,
      Map<String, Definition> functions, int opnum) {
    if (codeIndex == null) {
      codeIndex = opnum;
    } else {
      assert(codeIndex == opnum);
    }
    var offset = globals[target];
    if (offset != null) {
      return [B(3), B(offset)];
    } else {
      offset = locals[target];
      if (offset == null) {
        locals[target] = offset = locals.length;
      }
      return [B(203), B(offset)];
    }
  }
}

var outputRegExp =
    RegExp(r"^(?<indent> *)(print|output) *\( *(?<arg>'.*'|[A-Za-z]+|-?[0-9]+) *\) *$");

class Output extends Instruction {
  String arg;

  Output(RegExpMatch match) {
    arg = match.namedGroup('arg');
  }

  factory Output.tryParse(String line) {
    var match = outputRegExp.firstMatch(line);
    return match == null ? null : Output(match);
  }

  @override
  Iterable<String> get readVariables => RegExp(r'^[A-Za-z]*$').hasMatch(arg) ? [arg] : [];

  @override
  Iterable<String> get writeVariables => [];

  @override
  Iterable<String> toPython([int indent = 0]) sync* {
    yield '${''.padLeft(indent)}print($arg)';
  }

  @override
  List<BigInt> encode(Map<String, int> locals, Map<String, int> globals,
      Map<String, Definition> functions, int opnum) {
    if (codeIndex == null) {
      codeIndex = opnum;
    } else {
      assert(codeIndex == opnum);
    }
    var val = tryParseBigIntOrChar(arg);
    if (val != null) {
      return [B(104), val];
    } else {
      if (arg[0] == "'") {
        return jsonDecode('"${arg.substring(1,arg.length-1)}"').toString().codeUnits.expand((c) => [B(104), B(c)]).toList();
      } else {
        var offset = globals[arg];
        if (offset != null) {
          return [B(4), B(offset)];
        } else {
          offset = locals[arg];
          if (offset == null) {
            locals[arg] = offset = locals.length;
          }
          return [B(204), B(offset)];
        }
      }
    }
  }
}

var condRegExp = RegExp(
    r"^(?<indent> *)(?<control>if|while) (?<left>'.*'|[A-Za-z]+|-?[0-9]+) (?<op>==|!=|<|>|<=|>=) (?<right>'.*'|[A-Za-z]+|-?[0-9]+):$");

class Conditional extends Block {
  String control, left, right, op;

  Conditional(RegExpMatch match) {
    control = match.namedGroup('control');
    left = match.namedGroup('left');
    op = match.namedGroup('op');
    right = match.namedGroup('right');
  }

  factory Conditional.tryParse(String line) {
    var match = condRegExp.firstMatch(line);
    return match == null ? null : Conditional(match);
  }

  @override
  Iterable<String> get readVariables => [left, right].where((exp) => tryParseBigIntOrChar(exp) == null);

  @override
  Iterable<String> get writeVariables => [];

  @override
  Iterable<String> toPython([int indent = 0]) sync* {
    yield ''.padLeft(indent) + 'if $left $op $right:';
    for (var child in children) {
      yield* child.toPython(indent + 2);
    }
  }

  @override
  List<BigInt> encode(Map<String, int> locals, Map<String, int> globals,
      Map<String, Definition> functions, int opnum) {
    if (codeIndex == null) {
      codeIndex = opnum;
    } else {
      assert(codeIndex == opnum);
    }
    if (op == '>' || op == '<=') {
      op = op == '>' ? '<' : '>=';
      var tmp = left;
      left = right;
      right = tmp;
    }
    var codes = [
      B0,
      tryParseBigIntOrChar(left),
      tryParseBigIntOrChar(right),
      B(globals['_cmp']),
      B(1000),
      B(globals['_cmp']),
      null
    ];
    if (codes[1] != null) {
      codes[0] += B(100);
    } else if (globals[left] != null) {
      codes[1] = B(globals[left]);
    } else {
      codes[0] += B(200);
      codes[1] = B(locals[left] ??= locals.length);
    }
    if (codes[2] != null) {
      codes[0] += B(1000);
    } else if (globals[right] != null) {
      codes[2] = B(globals[right]);
    } else {
      codes[0] += B(2000);
      codes[2] = B(locals[right] ??= locals.length);
    }
    switch (op) {
      case '<':
        codes[0] += B(7);
        codes[4] += B(6);
        break;
      case '>=':
        codes[0] += B(7);
        codes[4] += B(5);
        break;
      case '==':
        codes[0] += B(8);
        codes[4] += B(6);
        break;
      case '!=':
        codes[0] += B(8);
        codes[4] += B(5);
        break;
      default:
        throw 'Conditional $op not implemented';
    }
    for (var child in children) {
      codes.addAll(
          child.encode(locals, globals, functions, opnum + codes.length));
    }
    if (control == 'while') {
      codes.addAll([B(1106), B(0), B(opnum)]);
    }
    codes[6] = B(opnum + codes.length);
    return codes;
  }
}

var funRegExp = RegExp(
    r'^(?<indent>)def (?<name>[A-Za-z]+)\( *(?<args>[A-Za-z]+( *, *[A-Za-z]+)*)? *\):$');

class Definition extends Block {
  String name;
  List<String> args;

  @override
  String toString() => 'def $name(${args.join(', ')}) @ $codeIndex';

  Definition(RegExpMatch match) {
    name = match.namedGroup('name');
    args = match.namedGroup('args')?.split(RegExp(r' *, *'))?.toList() ?? [];
    if (args.length != args.toSet().length) {
      throw 'Parameter names are not unique';
    }
  }

  factory Definition.tryParse(String line) {
    var match = funRegExp.firstMatch(line);
    return match == null ? null : Definition(match);
  }

  @override
  Iterable<String> get readVariables => [];

  @override
  Iterable<String> get writeVariables => [];

  @override
  Iterable<String> toPython([int indent = 0]) sync* {
    yield '${''.padLeft(indent)}def $name(${args.join(', ')}):';
    for (var child in children) {
      yield* child.toPython(indent + 2);
    }
  }

  @override
  List<BigInt> encode(Map<String, int> locals, Map<String, int> globals,
      Map<String, Definition> functions, int opnum) {
    if (codeIndex == null) {
      codeIndex = opnum;
    } else {
      assert(codeIndex == opnum);
      if (globals.keys.toSet().intersection(args.toSet()).isNotEmpty) {
        throw 'Parameters intersect with global variables';
      }
    }
    var returnValueCount = descendants
        .whereType<Return>()
        .map((ins) => ins.expr.length)
        .fold(0, max);
    if (!(lastChild is Return)) {
      // to ensure that execution never overflows function
      addChild(Return.tryParse('return'));
    }
    locals = {
      '_return_to': 0,
      for (int i = 0; i < args.length; ++i) args[i]: i + 1,
      for (int i = 0; i < returnValueCount; ++i)
        '_return_$i': args.length + 1 + i,
    };
    for (var local in descendants.expand((desc) => [...desc.readVariables, ...desc.writeVariables]).toSet()) {
      locals[local] ??= locals.length;
    }
    var codes = <BigInt>[];
    for (var child in children) {
      codes.addAll(
          child.encode(locals, globals, functions, opnum + codes.length));
    }
    return codes;
  }
}

var callRegExp = RegExp(
    r"^(?<indent> *)((?<target>[A-Za-z]+( *, *[A-Za-z]+)*) = )?(?<name>[A-Za-z]+)\((?<args>('.*'|[A-Za-z]+|-?[0-9]+)( *, *('.*'|[A-Za-z]+|-?[0-9]+))*)?\)$");

class Call extends Instruction {
  String name;
  List<String> args, targets;

  Call(RegExpMatch match) {
    targets = match.namedGroup('target')?.split(RegExp(r' *, *'))?.toList() ?? [];
    name = match.namedGroup('name');
    args = match.namedGroup('args')?.split(RegExp(r' *, *'))?.toList() ?? [];
  }

  factory Call.tryParse(String line) {
    var match = callRegExp.firstMatch(line);
    return match == null ? null : Call(match);
  }

  @override
  Iterable<String> get readVariables => args.where((arg) => tryParseBigIntOrChar(arg) == null);

  @override
  Iterable<String> get writeVariables => targets;

  @override
  Iterable<String> toPython([int indent = 0]) sync* {
    if (targets.isEmpty) {
      yield '${''.padLeft(indent)}$name(${args.join(', ')})';
    } else {
      yield '${''.padLeft(indent)}${targets.join(', ')} = $name(${args.join(', ')})';
    }
  }

  @override
  List<BigInt> encode(Map<String, int> locals, Map<String, int> globals,
      Map<String, Definition> functions, int opnum) {
    if (codeIndex == null) {
      codeIndex = opnum;
    } else {
      assert(codeIndex == opnum);
    }
    var codes = <BigInt>[];
    for (var i = 0 ; i < args.length ; ++i) {
      var code = [
        B(21001),
        tryParseBigIntOrChar(args[i]),
        B(0),
        B(locals.length + 1 + i)
      ];
      if (code[1] != null) {
        code[0] += B(100);
      } else {
        if (globals[args[i]] != null) {
          code[1] = B(globals[args[i]]);
        } else {
          code[0] += B(200);
          code[1] = B(locals[args[i]] ??= locals.length);
        }
      }
      codes.addAll(code);
    }
    codes.addAll([B(109), B(locals.length)]);
    codes.addAll([B(21101), B(opnum + codes.length + 7), B(0), B(0)]);
    codes.addAll([B(1106), B(0), B(functions[name]?.codeIndex ?? -1)]);
    codes.addAll([B(109), B(-locals.length)]);
    for (var i = 0 ; i < targets.length ; ++i) {
      var code = [
        B(1201),
        B(locals.length + 1 + i + (functions[name]?.args?.length ?? -1)),
        B(0),
        null
      ];
      if (globals[targets[i]] != null) {
        code[3] = B(globals[targets[i]]);
      } else {
        code[0] += B(20000);
        code[3] = B(locals[targets[i]] ??= locals.length);
      }
      codes.addAll(code);
    }

    return codes;
  }
}

var returnRegExp = RegExp(
    r"^(?<indent> *)return( +(?<expr>('.*'|[A-Za-z]+|-?[0-9]+)( *, *('.*'|[A-Za-z]+|-?[0-9]+))*))? *$");

class Return extends Instruction {
  List<String> expr;

  Return(RegExpMatch match) {
    expr = match.namedGroup('expr')?.split(RegExp(r' *, *')) ?? [];
  }

  factory Return.tryParse(String line) {
    var match = returnRegExp.firstMatch(line);
    return match == null ? null : Return(match);
  }

  @override
  Iterable<String> get readVariables => expr.where((exp) => tryParseBigIntOrChar(exp) == null).toList();

  @override
  Iterable<String> get writeVariables => [];

  @override
  Iterable<String> toPython([int indent = 0]) sync* {
    yield '${''.padLeft(indent)}return ${expr.join(', ')}';
  }

  @override
  List<BigInt> encode(Map<String, int> locals, Map<String, int> globals,
      Map<String, Definition> functions, int opnum) {
    if (codeIndex == null) {
      codeIndex = opnum;
    } else {
      assert(codeIndex == opnum);
    }
    var codes = <BigInt>[];
    for (var i = 0; i < expr.length; ++i) {
      var code = [
        B(21001),
        tryParseBigIntOrChar(expr[i]),
        B(0),
        B(locals['_return_$i'])
      ];
      if (code[1] != null) {
        code[0] += B(100);
      } else {
        if (globals[expr[i]] != null) {
          code[1] = B(globals[expr[i]]);
        } else {
          code[0] += B(200);
          code[1] = B(locals[expr[i]] ??= locals.length);
        }
      }
      codes.addAll(code);
    }
    codes.addAll([B(2106), B(0), B(0)]);
    return codes;
  }
}

class Main extends Block {
  @override
  Iterable<String> get readVariables => [];

  @override
  Iterable<String> get writeVariables => [];

  @override
  Iterable<String> toPython([int indent = 0]) sync* {
    yield '';
    for (var child in children.whereType<Definition>()) {
      yield* child.toPython(indent);
      yield '';
    }
    for (var child in children.where((child) => !(child is Definition))) {
      yield* child.toPython(indent);
    }
    yield '';
  }

  List<BigInt> toIntCode() => encode({}, {}, {}, 0);

  // layout: statements, functions, global variables, stack (local variables)
  @override
  List<BigInt> encode(Map<String, int> locals, Map<String, int> globals,
      Map<String, Definition> functions, int opnum) {
    if (codeIndex == null) {
      codeIndex = opnum;
    } else {
      assert(codeIndex == opnum);
    }
    locals = {'_cmp': 0}; // reserved comparison register
    globals = {'_cmp': 0};
    functions = {for (var func in descendants.whereType<Definition>()) func.name : func};
    var statements = children.where((child) => !(child is Definition)).toList();
    var funcs = children.whereType<Definition>().toList();
    var len = funcs.isNotEmpty ? 2 : 0; // initial stack offset setting
    for (var statement in statements) {
      len += statement.encode(locals, globals, functions, len).length;
    }
    len += 1; // exit code 99
    for (var func in funcs) {
      len += func.encode({}, globals, functions, len).length;
    }
    globals = {for (var e in locals.entries) e.key: e.value + len};
    len += globals.length;
    locals = {};
    var prog = funcs.isNotEmpty ? [B(109), B(len)] : <BigInt>[];
    for (var statement in statements) {
      prog.addAll(statement.encode(locals, globals, functions, prog.length));
    }
    prog.add(B(99));
    for (var function in funcs) {
      prog.addAll(function.encode(locals, globals, functions, prog.length));
    }
    return prog;
  }
}
