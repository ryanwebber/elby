# Elby Language

A language and toolchain targeting odd architectures.

## Planned Features

 * Static type system
 * Static variable allocation
 * Type-based overflow semantics
 * VM support (ex. interpreter mode in AGC)

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
 - [ ] VM modes

Targets:
 - `c`: Working as far as language features go
 - `agc`: Waiting on additional language features
