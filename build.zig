const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zeb", "src/main.zig");
    lib.linkSystemLibrary("c");
    lib.addPackagePath("network", "zig-network/network.zig");
    lib.setBuildMode(mode);
    lib.install();

    // time tests
    const time_tests = b.addTest("src/time.zig");
    time_tests.linkSystemLibrary("c");
    time_tests.setBuildMode(mode);

    // server tests
    const server_tests = b.addTest("src/server.zig");
    server_tests.linkSystemLibrary("c");
    server_tests.addPackagePath("network", "zig-network/network.zig");
    server_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&time_tests.step);
    test_step.dependOn(&server_tests.step);
}
