const types = @import("../types.zig");

pub const Token = struct {
    id: Id,
    range: []const u8,
    lineno: usize,

    pub const Id = union(enum) {
        template,
        identifier,
        assignment,
        number_literal: types.Number,
        source_block_open,
        source_block_close,
        plus,
        minus,
        star,
        kwd_let,
        eof,
    };

    pub fn description(self: *Token) []const u8 {
        return self.range;
    }
};
