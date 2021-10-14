
test {
    _ = @import("scanner.zig");
    _ = @import("tokenizer.zig");
    _ = @import("parser.zig");
    _ = @import("parser2.zig");

    _ = @import("tests/index.zig");
}
