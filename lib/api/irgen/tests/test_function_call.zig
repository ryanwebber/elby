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
        \\T4 := L1 + P0
        \\foo(abc:def:)/P0[0] := T3[0]
        \\foo(abc:def:)/P1[0] := T4[0]
        \\call foo(abc:def:)
        \\call bar()
        \\
        ;

    try utils.expectIR(std.testing.allocator, source, "main(z:)", expectedIR);
}

test "function return ir generation" {

    const source =
        \\fn add(a: i, b: i) -> i {
        \\  return a + b;
        \\}
        ;

    const expectedIR =
        \\T0 := P0 + P1
        \\RET[0] := T0[0]
        \\return
        \\
        ;

    try utils.expectIR(std.testing.allocator, source, "add(a:b:)", expectedIR);
}

test "function void return" {

    const source =
        \\fn test(a: i, b: i) {
        \\  return;
        \\}
        ;

    const expectedIR =
        \\return
        \\
        ;

    try utils.expectIR(std.testing.allocator, source, "test(a:b:)", expectedIR);
}

test "function param smashing" {

    const source =
        \\fn test() {
        \\  foo(a: 1, b: foo(a: 2, b: 3));
        \\}
        \\
        \\fn foo(a: i, b: i) -> i {
        \\  return a + b;
        \\}
        ;

    const expectedIR =
        \\T0 := int(1)
        \\T1 := int(2)
        \\T2 := int(3)
        \\foo(a:b:)/P0[0] := T1[0]
        \\foo(a:b:)/P1[0] := T2[0]
        \\call foo(a:b:)
        \\T3[0] := foo(a:b:)/RET[0]
        \\foo(a:b:)/P0[0] := T0[0]
        \\foo(a:b:)/P1[0] := T3[0]
        \\call foo(a:b:)
        \\
        ;

    try utils.expectIR(std.testing.allocator, source, "test()", expectedIR);
}
