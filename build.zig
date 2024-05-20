const std = @import("std");

pub fn build(b: *std.Build) void {
    const entry = b.path("src/root.zig");
    const lib = b.addModule("datetime", .{ .root_source_file = entry });
    const lib_unit_tests = b.addTest(.{ .root_source_file = entry });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const demo = b.addTest(.{
        .name = "demo",
        .root_source_file = b.path("demos.zig"),
    });
    demo.root_module.addImport("datetime", lib);
    const run_demo = b.addRunArtifact(demo);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_demo.step);
}
