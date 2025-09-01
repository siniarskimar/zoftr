const std = @import("std");
const geom = @import("geometry.zig");
const vec3Cross = @import("linmath.zig").vec3Cross;
const vecMagSquared = @import("linmath.zig").vecMagSquared;
const matDet = @import("linmath.zig").matDet;

data: []u8,
format: PixelFormat,
width: u32,
height: u32,

const Surface = @This();

pub fn sample(self: *const @This(), x: u32, y: u32) []u8 {
    const offset: usize = self.width * y + x;
    return self.data[offset * self.format.byteSize() ..][0..self.format.byteSize()];
}

pub fn drawRect(self: *@This(), rect: geom.Rect([2]u32)) void {
    for (rect.@"0"[1]..rect.@"1"[1]) |y| {
        for (rect.@"0"[1]..rect.@"1"[1]) |x| {
            if (x >= self.width or y >= self.height) continue;

            const pix = self.sample(@intCast(x), @intCast(y));
            pix[0..3].* = @splat(128);
        }
    }
}

pub fn drawTriangle(self: *@This(), points: [3][2]u32) void {
    const bounding_box = geom.findBoundingBox([2]u32, &points);

    const V = @Vector(2, i64);
    const a: V = points[0];
    const b: V = points[1];
    const c: V = points[2];

    const ab: V = b - a;
    const ac: V = c - a;
    const area: f32 = @abs(matDet([2][2]f32{
        .{ @floatFromInt(ab[0]), @floatFromInt(ab[1]) },
        .{ @floatFromInt(ac[0]), @floatFromInt(ac[1]) },
    }));

    if (std.math.approxEqAbs(f32, area, 0, std.math.floatEps(f32))) {
        return;
    }

    for (bounding_box.@"0"[1]..bounding_box.@"1"[1]) |p_y| {
        for (bounding_box.@"0"[0]..bounding_box.@"1"[0]) |p_x| {
            const p: V = .{ @intCast(p_x), @intCast(p_y) };
            const ap = p - a;
            const cp = p - c;
            const bc = c - b;

            const a1 = @abs(matDet([2][2]f32{
                .{ @floatFromInt(ap[0]), @floatFromInt(ap[1]) },
                .{ @floatFromInt(ab[0]), @floatFromInt(ab[1]) },
            }));
            const a2 = @abs(matDet([2][2]f32{
                .{ @floatFromInt(ap[0]), @floatFromInt(ap[1]) },
                .{ @floatFromInt(ac[0]), @floatFromInt(ac[1]) },
            }));
            const a3 = @abs(matDet([2][2]f32{
                .{ @floatFromInt(cp[0]), @floatFromInt(cp[1]) },
                .{ @floatFromInt(bc[0]), @floatFromInt(bc[1]) },
            }));

            const w1 = a1 / area;
            const w2 = a2 / area;
            const w3 = a3 / area;

            if (@abs(w1 + w2 + w3 - 1) > std.math.floatEps(f32)) {
                continue;
            }

            const pix = self.sample(@intCast(p_x), @intCast(p_y));
            pix[0..3].* = @splat(128);

            // const a1: f32 = @abs

            // const w1: f32 = vecMagSquared(vec3Cross(f32, .{}, b: [3]S))
            // const w2: f32 = 0;
            // const w3: f32 = 1 - w1 - w2;
        }
    }
}

pub fn clear(self: *@This()) void {
    @memset(self.data, 0);
}

pub const PixelFormat = enum {
    r8,
    rg8,
    rgb8,
    rgba8,
    bgr8,
    bgra8,

    pub fn bitSize(self: @This()) u8 {
        return switch (self) {
            .r8 => 8,
            .rg8 => 16,
            .rgb8, .bgr8 => 24,
            .rgba8, .bgra8 => 32,
        };
    }

    pub fn byteSize(self: @This()) u8 {
        return switch (self) {
            inline else => |f| blk: {
                const base: u8 = f.bitSize() / 8;
                const rem: u8 = f.bitSize() % 8;
                const offset = rem >> @intCast(@typeInfo(@TypeOf(rem)).int.bits - @clz(rem));
                break :blk base + offset;
            },
        };
    }

    pub fn Tuple(comptime format: @This()) type {
        return switch (format) {
            .r8 => struct { u8 },
            .rg8 => struct { u8, u8 },
            .rgb8, .bgr8 => struct { u8, u8, u8 },
            .rgba8, .bgra8 => struct { u8, u8, u8, u8 },
        };
    }
};

test sample {
    var data = [_]u8{ 102, 244, 104, 200 };
    var surface: @This() = .{
        .data = data[0..],
        .format = .r8,
        .width = 2,
        .height = 2,
    };

    try std.testing.expectEqualSlices(u8, data[0..1], surface.sample(0, 0));
    try std.testing.expectEqualSlices(u8, data[1..2], surface.sample(1, 0));

    surface.width = 1;
    surface.format = .rg8;
    try std.testing.expectEqualSlices(u8, data[0..2], surface.sample(0, 0));
    try std.testing.expectEqualSlices(u8, data[2..4], surface.sample(0, 1));

    surface.height = 1;
    surface.format = .rgba8;

    try std.testing.expectEqualSlices(u8, data[0..4], surface.sample(0, 0));
}

test "set_in_sample" {
    var data: [(2 * 2) * 2]u8 = undefined;
    var surface: @This() = .{
        .data = data[0..],
        .width = 2,
        .height = 2,
        .format = .rg8,
    };

    // checkerboard pattern
    var odd: bool = true;
    for (0..surface.height) |y| {
        for (0..surface.width) |x| {
            const pix = surface.sample(@intCast(x), @intCast(y));
            for (pix) |*comp| {
                comp.* = if (odd) 255 else 0;
            }
            odd = !odd;
        }
    }

    try std.testing.expectEqualSlices(u8, &.{ 255, 255, 0, 0, 255, 255, 0, 0 }, data[0..]);
}
test "PixelFormat.byteSize" {
    try std.testing.expectEqual(1, PixelFormat.r8.byteSize());
    try std.testing.expectEqual(2, PixelFormat.rg8.byteSize());
    try std.testing.expectEqual(3, PixelFormat.rgb8.byteSize());
    try std.testing.expectEqual(4, PixelFormat.rgba8.byteSize());
}
