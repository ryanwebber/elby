const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("elby-cli", "src/main.zig");
    exe.addPackage(.{
        .name = "elby",
        .path = .{
            .path = "lib/api/api.zig"
        }
    });
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the elby command line tool");
    run_step.dependOn(&run_cmd.step);

    const lib_tests_step = b.step("test-lib", "Run library tests");
    const lib_tests_api_unit_cmd = b.addTest("lib/api/api.zig");
    lib_tests_api_unit_cmd.setTarget(target);
    lib_tests_api_unit_cmd.setBuildMode(mode);
    lib_tests_step.dependOn(&lib_tests_api_unit_cmd.step);

    const cli_tests_step = b.step("test-cli", "Run cli tests");
    const cli_tests_api_unit_cmd = b.addTest("src/main.zig");
    cli_tests_api_unit_cmd.setTarget(target);
    cli_tests_api_unit_cmd.setBuildMode(mode);
    cli_tests_step.dependOn(&cli_tests_api_unit_cmd.step);

    const tests_step = b.step("test", "Run all tests");
    tests_step.dependOn(lib_tests_step);
    tests_step.dependOn(cli_tests_step);
}
