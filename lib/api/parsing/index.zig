
test {
    _ = @import("scanner.zig");
    _ = @import("tokenizer.zig");
    _ = @import("parser.zig");

    _ = @import("tests/index.zig");
}
