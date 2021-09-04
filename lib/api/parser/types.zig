const std = @import("std");

pub const Parsers = struct {
    const Expect = @import("expect.zig").Expect;
};

test {
    _ = Parsers.Expect;
}
