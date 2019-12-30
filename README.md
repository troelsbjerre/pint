# pint

## A simple compiler from at subset of Python to IntCode, as defined in [Advent of Code 2019](https://adventofcode.com/2019/day/9). 

## Use

You must have [Dart](https://dart.dev) installed. If you clone this repository, you can compile with:

```
pub run pintc.dart examples/div.pint div.int
```

and then use your own IntCode interpreter to run the generated `div.int` program, or use the one included here, by running:

```
pub run intcode.dart div.int
```

## Caveats

The compiler is written in Dart, but is otherwise entirely (s)elf contained.
It supports functions (with multiple arguments and multiple return values), but
other than that, it is only a small step beyond an assembler. It cannot parse
complicated expressions; most lines of code are one-to-one IntCode instructions
There is currently very little feedback in terms of static analysis, so it is
highly recommended to compile to python (by specifying a `.py` file as output:
`pintc source.pint target.py`) and using tools for python to debug. For most
errors, the compiler will simply reply `Cannot parse:` and then the line number
and line.

## Syntax

Currently, the following constructions are supported:

### Variables

Any sequence of upper and lower case letter are valid variable names.
Currently, variables are global if used outside of a function definition, and
otherwise they are local to the function. Pythons `global` declaration and
implicit globals have not been implemented yet.

### Operations on variables

Addition and multiplication, where the operands can also be (positive/negative) constants

```
a = b + c
a = b * c
```

This includes the shorthand

```
a += b
a *= b
```

Or simply assignment

```
a = b
```

### Input and output

```
a = input()
output(a)
```

Alternatively, to be consistent with generated Python:

```
a = int(input())
print(a)
```

### Blocks

As in Python, code blocks are indentation controlled. `pint` is slightly more
relaxed, but not in a helpful way: Any indented line of code is a child of the
most recent line of code will less indentation. A line without such a parent is
part of the main program.

### Conditionals

Simple `if`:

```
if a < b:
  max = b
```

Currently, `else` and `elif` is not supported

Simple `while`:

```
while a < b:
  sum += a
  a += 1
```

### Function declaration

```
def max(a, b):
  if a < b:
    return b
  return a
```

The `def` must not be indented.

Recursion is supported, and functions can take any number of arguments and
return values.

Basic `IntCode` does not have a division operator, but with functions, we can write our own:

```
def divide(dividend, divisor):
  if dividend < divisor:
    return 0, dividend
  doubledivisor = divisor * 2
  halfquotient, remainder = divide(dividend, doubledivisor)
  quotient = halfquotient * 2
  if remainder >= divisor:
    divisor *= -1
    remainder += divisor
    quotient += 1
  return quotient, remainder
```
