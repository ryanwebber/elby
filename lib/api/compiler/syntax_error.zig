const Token = @import("token.zig").Token;

pub const SyntaxError = struct {
    line: usize,
    offset: usize,

    pub fn init(at: *Token) SyntaxError {
        return .{
            .line = at.line,
            .offset = at.offset,
        };
    }
};
