const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const utils = @import("../../testing/utils.zig");

test "function call ir generation" {

    const source =
        \\fn main(z: i) {
        \\  let x: i = 0;
        \\  let y: i = 1;
        \\  foo(abc: x + 3, def: y + z);
        \\  bar();
        \\}
        \\
        \\fn foo(abc: i, def: i) {}
        \\fn bar() {}
        ;

    const expectedIR =
        \\T0 := int(0)
        \\L0[0] := T0[0]
        \\T1 := int(1)
        \\L1[0] := T1[0]
        \\T2 := int(3)
        \\T3 := L0 + T2
        \\foo(abc:def:)/P0[0] := T3[0]
        \\T4 := L1 + P0
        \\foo(abc:def:)/P1[0] := T4[0]
        \\call foo(abc:def:)
        \\call bar()
        \\
        ;

    try utils.expectIR(std.testing.allocator, source, "main(z:)", expectedIR);
}