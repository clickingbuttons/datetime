const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const datetime = b.addModule("datetime", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const lib = b.addStaticLibrary(.{
        .name = "datetime",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const demo = b.addTest(.{
        .name = "demo",
        .root_source_file = .{ .path = "./demos.zig" },
        .target = target,
        .optimize = optimize,
    });
    demo.root_module.addImport("datetime", datetime);
    const run_demo = b.addRunArtifact(demo);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_demo.step);
}
