# Elby Language

A language and toolchain targeting the Apollo Guidance Computer.

## Features

 * Static type system
 * Static variable allocation
 * Type-based overflow semantics
 * Multi-bank support
 * Interpreter-supported types (ex. Vectors)
 * Standard library APIs for IO, DSKY, etc

```
@import("something.lb)

// functions
fn add(a: int15, b: int15) -> int15? {

    // addition may cause overflow
    return a + b;
}

fn main() {
    // variables
    let i: int15 = 10;
    let j: int15 = i + 1;

    // function call + type inference
    let k = add(a: i, b: j);

    // overflow unwrapping + control flow
    if let m = k {
        // ...
    } else if {
        // ...
    } else {
        // ...
    }

    // loops
    for (let x = 0; x < 2; x++) {
        // ...
    }

    // inline asm
    @asm("TC", 0);

    // interpreter types
    let vec: Vec3 = Vec3(x: 1, y: 2, z: 3);

    // struct initialization
    let point = Point(x: 0, y: 0);

    // auto-self capturing functions
    let d = point.manhattanDistance();

    // reference types
    makeZero(&i);

    // reference types with auto-self capturing
    point.zero();

    // blocks, end with a yield expression
    let d: int = {
        let a: int = 1;
        let b: int = 2;
        yield a + b;
    }
}

// structs
struct Point {
    let x: int15;
    let y: int15;

    fn manhattanDistance(self: Point) -> f15? {
        return self.x * self.x + self.y * self.y;
    }

    fn zero(self: ref Point) {
        self.x = 0;
        self.y = 0;
    }
}

fn makeZero(x: ref int15) -> {
    x = 0;
}

// types (replacement for structs)
// needs switch statement, self-function syntax,
// and logic around single-constructor types

type Point
    = Vec2(x: Int, y: Int)
    | Vec3(x: Int, y: Int, z: Int)
    ;

type Optional(T) = Some(value: T) | None;
type Direction = Up | Down | Left | Right;
type Fraction = Fraction(numerator: float, denominator: float)

let point: Point = Vec2(x: 0, y: 0);
let maybePoint: Optional(Point) = Some(value: Point);
let dir: Direction = Up;

match (maybePoint) {
    (container: Some) => {
        yield container.value;
    };
    case None => 1;
}

```

## Progress

Current language features:
 - [x] Basic types
 - [x] Basic expressions
 - [x] If statements
 - [x] While loops
 - [x] Functions and calls
 - [x] Extern functions
 - [x] Comments
 - [ ] Unary operators (-, !)
 - [x] Boolean logic operators (<, >, <=, >=)
 - [ ] Bitwise operators (|, &, ~, ^)
 - [x] Blocks
 - [ ] Ref types
 - [ ] Complex types (structs / sum types)
 - [ ] Optionals, math overflows
 - [ ] Match expressions
 - [ ] Inline asm

Targets:
 - `c`: Working as far as language features go
 - `agc`: Waiting on additional language features

## Contributing

### Toolchain

The toolchain is split into multiple binaries. You can build them with the various
`zig build` steps, or, just call make:

```bash
# Build executables
make build

# Install the executables
make install

# Run the unit tests and the compiler tests
make test
```

### Parser

The parser is generated from a tree-sitter grammar. The generated `c` source files
are checked into the repo and only need to be rebuilt when the grammar changes. To generate
the parser, you'll need an installation of `npm` and `node`, and you'll also need to clone
the tree-sitter submodule with `git submodule init && git submodule update`. At this point,
you can generate the parser source files with:

```bash
# Generate the parser
make generate-parser

# Test the parser
make test-parser
```
