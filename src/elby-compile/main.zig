const std = @import("std");
const elby = @import("elby");
const argscan = @import("argscan");
const defines = @import("build-options");

const ArgumentParser = argscan.Parser(&.{
    .usages = &.{
        defines.name ++ " --target c [--options] " ++ argscan.StandardHints.file,
        defines.name ++ " --target agc [--options] " ++ argscan.StandardHints.file,
        defines.name ++ " --help",
        defines.name ++ " --version",
    },
    .description =
        \\Compiles the provided elby source file.
        ,
    .options = &.{
        argscan.StandardOptions.showHelp,
        argscan.StandardOptions.showVersion,
    },
    .arguments = &.{
        .{
            .name = "target",
            .description = "The target architecture to compile for.",
            .parameterHint = "[c|agc]",
            .forms = &.{
                "-t",
                "--target",
            },
        },
        .{
            .name = "cOutput",
            .description = "File to write generated c code to.",
            .parameterHint = argscan.StandardHints.file,
            .forms = &.{
                "-o",
                "--c-output",
            },
        },
    },
});

pub const targets = std.ComptimeStringMap(enum {
    c,
    agc,
}, .{
    .{ "c",   .c },
    .{ "agc", .agc },
});

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer { _ = gpa.deinit(); }

    var allocator = &gpa.allocator;

    const args = try std.process.argsAlloc(allocator);
    defer { std.process.argsFree(allocator, args); }

    const parse = try ArgumentParser.parse(allocator, args[1..]);
    defer { parse.deinit(); }

    const errWriter = std.io.getStdErr().writer();

    switch (parse.result) {
        .ok => |conf| {
            if (conf.options.showHelp) {
                try errWriter.print("{s}\n", .{ ArgumentParser.helpText });
                return;
            } else if (conf.options.showVersion) {
                try errWriter.print("Version: {s}-{s}\n", .{ defines.name, defines.version });
                return;
            }

            const sourceFile = if (conf.unparsedArguments.len == 1) conf.unparsedArguments[0]
                else if (conf.unparsedArguments.len == 0) {
                    try fatal("Source file must be provided.", .{});
                    return;
                } else {
                    try fatal("Multiple source files provided.", .{});
                    return;
                };

            if (targets.get(conf.arguments.target)) |target| switch (target) {
                .agc => {
                    try fatal("AGC target currently not supported.", .{});
                    std.os.exit(1);
                },
                .c => {
                    var options = getCTargetOptions(conf) catch |e| {
                        try fatal("Unable to write to output path: {s} ({any}).", .{ conf.arguments.cOutput, e });
                        return;
                    };

                    try compileWithTarget(elby.targets.c, allocator, sourceFile, &options);
                },
            } else if (conf.arguments.target.len == 0) {
                try fatal("Target must be specified.\n", .{});
                try errWriter.print("{s}\n", .{ ArgumentParser.helpText });
                std.os.exit(1);
            } else {
                try fatal("Unknown target: '{s}'.\n", .{ conf.arguments.target });
                try errWriter.print("{s}\n", .{ ArgumentParser.helpText });
                std.os.exit(1);
            }
        },
        .fail  => |err| {
            try err.format(errWriter);
            try errWriter.print("\n\n", .{});
            try errWriter.print("{s}\n", .{ ArgumentParser.helpText });
            std.os.exit(1);
        }
    }
}

fn compileWithTarget(comptime TargetType: type, allocator: *std.mem.Allocator, filename: []const u8, options: *TargetType.OptionsType) !void {
    var moduleLoader = elby.ModuleResolver.init(allocator);
    defer { moduleLoader.deinit(); }

    const absModulePath = std.fs.cwd().realpathAlloc(allocator, filename) catch |err| {
        try fatal("Unable to open module: {s} ({any}).", .{ filename, err });
        return;
    };

    defer { allocator.free(absModulePath); }

    const module = try moduleLoader.resolveAbsolute(absModulePath);

    var context = elby.GeneratorContext.init(allocator);
    defer { context.deinit(); }

    var pipeline = elby.Pipeline(TargetType).init(allocator, &context);
    defer { pipeline.deinit(); }

    const result = try pipeline.compileModule(module, options);
    switch (result) {
        .syntaxError => |errs| {
            return elby.utils.reportSyntaxErrors(errs, std.io.getStdErr().writer());
        },
        else => {}
    }
}

fn getCTargetOptions(conf: ArgumentParser.Parse.Success) !elby.targets.c.OptionsType {

    const flags = std.fs.File.CreateFlags {};
    const file = try std.fs.cwd().createFile(conf.arguments.cOutput, flags);

    const stream = std.io.StreamSource {
        .file = file,
    };

    return elby.targets.c.OptionsType {
        .outputStream = stream,
    };
}

fn fatal(comptime format: []const u8, args: anytype) !void {
    const errWriter = std.io.getStdErr().writer();
    try errWriter.print("[Error] ", .{});
    try errWriter.print(format, args);
    try errWriter.print("\n", .{});
}

test "sanity check" {
    try std.testing.expect(true);
}
