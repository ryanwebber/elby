const std = @import("std");
const _module = @import("module.zig");
const _pipeline = @import("pipeline.zig");
const _compiler = @import("irgen/compiler.zig");
const _function = @import("irgen/function.zig");
const _scheme = @import("irgen/scheme.zig");

pub const Module = _module.Module;
pub const ModuleResolver = _module.ModuleResolver;
pub const Pipeline = _pipeline.Pipeline;
pub const StageResult = _pipeline.StageResult;
pub const FunctionPrototype = _function.FunctionPrototype;
pub const FunctionDefinition = _function.FunctionDefinition;
pub const FunctionBody = _function.FunctionBody;
pub const FunctionLayout = _function.FunctionLayout;
pub const ExternFunction = _function.ExternFunction;
pub const Scheme = _scheme.Scheme;
pub const FunctionRegistry = _scheme.FunctionRegistry;
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
