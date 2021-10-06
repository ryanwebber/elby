const std = @import("std");
const elby = @import("elby");

pub fn main() anyerror!void {
    std.log.info("Message: {s}", .{ elby.hello() });
}

test "sanity check" {
    try std.testing.expect(true);
}
