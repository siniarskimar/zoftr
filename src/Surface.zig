const std = @import("std");

data: []u8,
format: PixelFormat,
width: u32,
height: u32,

const Surface = @This();

pub fn sample(self: *const @This(), x: u32, y: u32) []u8 {
    const offset: usize = self.width * y + x;
    return self.data[offset * self.format.byteSize() ..][0..self.format.byteSize()];
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
