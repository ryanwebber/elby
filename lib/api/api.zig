const std = @import("std");
const _module = @import("module.zig");

pub const Module = _module.Module;
pub const ModuleResolver = _module.ModuleResolver;
pub const Pipeline = @import("pipeline.zig").Pipeline;
pub const SyntaxError = @import("parsing/syntax_error.zig").SyntaxError;
pub const GeneratorContext = @import("codegen/context.zig").Context;

pub const utils = @import("utils.zig");

pub const targets = struct {
    pub const c = @import("codegen/targets/c99/target.zig").Target;
};

pub fn hello() []const u8 {
    return "Hello world!";
}

test {
    _ = @import("parsing/index.zig");
    _ = @import("irgen/index.zig");
    _ = @import("codegen/target.zig");
    _ = @import("pipeline.zig");

    _ = targets.c;
}
