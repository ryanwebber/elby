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
```
