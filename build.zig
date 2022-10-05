const std = @import("std");

const version = "0.1.0";

const Command = struct {
    name: []const u8,
    description: []const u8,
};

const commands: []const Command = &.{
    .{
        .name = "elby-check",
        .description = "Checks for syntax and semantic errors without compiling."
    },
    .{
        .name = "elby-compile",
        .description = "Compiles elby source code."
    },
    .{
        .name = "elby-dump-ir",
        .description = "Prints out the IR instructions for elby source code."
    },
};

pub fn build(b: *std.build.Builder) void {

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // Create a test step that runs all source tests
    const tests_step = b.step("test", "Run all tests");

    // Build each command executable
    inline for (commands) |command| {
        const main = std.fmt.comptimePrint("src/{s}/main.zig", .{ command.name });
        const exe = b.addExecutable(command.name, main);
        exe.addPackagePath("elby", "lib/api/api.zig");
        exe.addPackagePath("argscan", "lib/argscan/argscan.zig");

        const exe_options = b.addOptions();
        exe.addOptions("build-options", exe_options);

        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        exe_options.addOption([]const u8, "version", version);
        exe_options.addOption([]const u8, "name", command.name);

        const test_command = std.fmt.comptimePrint("test-{s}", .{ command.name });
        const test_description = std.fmt.comptimePrint("Run the {s} tests", .{ command.name });
        const cli_tests_cmd = b.addTest(main);
        var cli_tests_step = b.step(test_command, test_description);
        cli_tests_cmd.setTarget(target);
        cli_tests_cmd.setBuildMode(mode);
        cli_tests_step.dependOn(&cli_tests_cmd.step);
        tests_step.dependOn(cli_tests_step);
    }

    const lib_tests_step = b.step("test-lib", "Run library tests");
    const lib_tests_api_unit_cmd = b.addTest("lib/api/api.zig");
    lib_tests_api_unit_cmd.setTarget(target);
    lib_tests_api_unit_cmd.setBuildMode(mode);
    lib_tests_step.dependOn(&lib_tests_api_unit_cmd.step);

    tests_step.dependOn(lib_tests_step);
}
