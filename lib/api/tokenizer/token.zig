
pub const TokeRef = struct {
    token: Token,
    range: []const u8,
    lineno: usize,

    pub fn description(self: *TokeRef) []const u8 {
        return self.range;
    }
};

pub const Token = union(enum) {
    identifier,
    eof,
    assignment,
    equality
};
