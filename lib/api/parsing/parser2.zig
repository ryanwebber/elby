const std = @import("std");
const ast = @import("ast.zig");
const errors = @import("../error.zig");

const SyntaxError = @import("syntax_error.zig").SyntaxError;

const c = @cImport({
    @cInclude("parser.h");
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_elby() *const c.TSLanguage;

const ts = struct {
    pub const RawParser = c.TSParser;
    pub const RawParse = c.TSTree;
    pub const RawNode = c.TSNode;
    pub const RawCursor = c.TSTreeCursor;

    pub fn new_parser() !*RawParser {
        var parser = c.ts_parser_new() orelse {
            return std.mem.Allocator.Error.OutOfMemory;
        };

        if (!c.ts_parser_set_language(parser, tree_sitter_elby())) {
            return errors.fatal("Unexpected parser language mis-match.", .{});
        }

        return parser;
    }

    pub fn free_parser(parser: *RawParser) void {
        c.ts_parser_delete(parser);
    }

    pub fn parse_string(parser: *RawParser, source: []const u8) !*RawParse {
        return c.ts_parser_parse_string(parser, null, source.ptr, @intCast(u32, source.len)) orelse {
            return std.mem.Allocator.Error.OutOfMemory;
        };
    }

    pub fn free_parse(parse: *RawParse) void {
        c.ts_tree_delete(parse);
    }
};

pub const AbstractParse = struct {
    root: *ast.Program,
};

pub const ConcreteParse = struct {
    rawTree: *ts.RawParse,

    pub fn deinit(self: *ConcreteParse) void {
        ts.free_parse(self.rawTree);
    }

    pub fn toAbstractTree(self: *const ConcreteParse, arena: *std.heap.ArenaAllocator) !AbstractParse {
        _ = self;
        _ = arena;
        unreachable;
    }

    pub fn errorIterator() ErrorIterator {
        return .{};
    }

    pub const ErrorIterator = struct {

        cursor: ts.RawCursor,

        const Self = @This();

        pub fn next(self: *Self) ?SyntaxError {
            _ = self;
            return null;
        }
    };
};

pub const ParseResult = struct {
    concreteParse: ConcreteParse,

    const Self = @This();

    fn init(rawTree: *ts.RawParse) Self {
        return .{
            .concreteParse = .{
                .rawTree = rawTree,
            }
        };
    }

    fn deinit(self: *ParseResult) void {
        self.concreteParse.deinit();
    }
};

pub const ParserBuilder = struct {
    pub fn parse(source: []const u8) !ParseResult {
        const parser = try ts.new_parser();
        defer { ts.free_parser(parser); }

        const parseTree = try ts.parse_string(parser, source);

        return ParseResult.init(parseTree);
    }
};

test {
    var parse = try ParserBuilder.parse("[0, null]");
    const root = c.ts_tree_root_node(parse.concreteParse.rawTree);
    std.debug.print("\n\nGot root node: {s}\n\n", .{ c.ts_node_type(root) });
    defer { parse.deinit(); }
}
