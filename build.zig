const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zeb", "src/main.zig");
    lib.addPackagePath("network", "zig-network/network.zig");
    lib.setBuildMode(mode);
    lib.install();

    // server tests
    const server_tests = b.addTest("src/server.zig");
    server_tests.addPackagePath("network", "zig-network/network.zig");
    server_tests.setBuildMode(mode);
    const test_step = b.step("test", "Run src/server.zig tests");
    test_step.dependOn(&server_tests.step);
}
