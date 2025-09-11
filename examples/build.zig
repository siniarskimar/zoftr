const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const check_step = b.step("check", "Build without emitting binaries");

    const zoftr_dep = b.dependency("zoftr", .{
        .target = target,
        .optimize = optimize,
    });
    const zoftr_mod = zoftr_dep.module("zoftr");

    _ = addExample(b, check_step, "shapes", .{
        .root_source_file = b.path("shapes/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoftr", .module = zoftr_mod },
        },
    });

    _ = addExample(b, check_step, "checkerboard", .{
        .root_source_file = b.path("checkerboard/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoftr", .module = zoftr_mod },
        },
    });
}

pub fn addExample(
    b: *std.Build,
    check_step: *std.Build.Step,
    name: []const u8,
    options: std.Build.Module.CreateOptions,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(options),
    });
    b.installArtifact(exe);

    check_step.dependOn(&b.addExecutable(.{
        .name = b.fmt("check-{s}", .{name}),
        .root_module = exe.root_module,
    }).step);

    return exe;
}
