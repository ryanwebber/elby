
pub const Token = struct {
    id: Id,
    range: []const u8,
    lineno: usize,

    pub const Id = union(enum) {
        template,
        identifier,
        source_block_open,
        source_block_close,
        eof,
    };

    pub fn description(self: *Token) []const u8 {
        return self.range;
    }
};
