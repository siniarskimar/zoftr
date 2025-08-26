const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zoftr_dep = b.dependency("zoftr", .{
        .target = target,
        .optimize = optimize,
    });
    const zoftr_mod = zoftr_dep.module("zoftr");

    const shapes_exe = b.addExecutable(.{
        .name = "example-shapes",
        .root_module = b.createModule(.{
            .root_source_file = b.path("shapes/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    shapes_exe.root_module.addImport("zoftr", zoftr_mod);
    b.installArtifact(shapes_exe);

    const check_step = b.step("check", "Build without emitting binaries");
    check_step.dependOn(&b.addExecutable(.{
        .name = "check-shapes",
        .root_module = shapes_exe.root_module,
    }).step);
}
