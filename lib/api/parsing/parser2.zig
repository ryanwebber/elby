const std = @import("std");

const c = @cImport({
    @cInclude("parser.h");
    @cInclude("tree_sitter/api.h");
});

const ts = struct {
    pub const Parser = c.TSParser;

    pub fn new_parser() ?*Parser {
        return c.ts_parser_new();
    }

    pub fn free_parser(parser: *Parser) void {
        c.ts_parser_delete(parser);
    }
};

pub const Parser = struct {
    impl: *ts.Parser,

    const Self = @This();

    pub fn init() !Self {
        const impl = ts.new_parser() orelse {
            return std.mem.Allocator.Error.OutOfMemory;
        };

        return Self {
            .impl = impl,
        };
    }

    pub fn deinit(self: *Parser) void {
        ts.free_parser(self.impl);
    }
};

test {
    var parser = try Parser.init();
    defer { parser.deinit(); }

    const source = "[1, null]";
    const tree = c.ts_parser_parse_string(parser.impl, null, source, source.len);
    defer { c.ts_tree_delete(tree); }
}
