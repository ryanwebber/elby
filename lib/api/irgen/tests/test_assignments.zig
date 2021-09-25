const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const utils = @import("../../testing/utils.zig");

test "assignment ir generation" {

    const source =
        \\fn main() {
        \\  let x = 5 - 3 * 2 / (0x1 + 0);
        \\  let y = x * x;
        \\}
        ;

    const expectedIR =
        \\S0 := int(5)
        \\S1 := int(3)
        \\S2 := int(2)
        \\S3 := S1 * S2
        \\S4 := int(1)
        \\S5 := int(0)
        \\S6 := S4 + S5
        \\S7 := S3 / S6
        \\S8 := S0 - S7
        \\L120[0] := S8[0]
        \\S9 := L120 * L120
        \\L121[0] := S9[0]
        \\
        ;

    try utils.expectIR(std.testing.allocator, source, expectedIR);
}
