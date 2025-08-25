const std = @import("std");

data: []u8,
width: u32,
height: u32,
component_count: u8,

pub fn sample(self: *const @This(), x: u32, y: u32) []u8 {
    const offset: usize = self.width * y + x;
    return self.data[offset * self.component_count ..][0..self.component_count];
}

test sample {
    var data = [_]u8{ 102, 244, 104, 200 };
    var surface: @This() = .{
        .data = data[0..],
        .width = 2,
        .height = 2,
        .component_count = 1,
    };

    try std.testing.expectEqualSlices(u8, data[0..1], surface.sample(0, 0));
    try std.testing.expectEqualSlices(u8, data[1..2], surface.sample(1, 0));

    surface.width = 1;
    surface.component_count = 2;
    try std.testing.expectEqualSlices(u8, data[0..2], surface.sample(0, 0));
    try std.testing.expectEqualSlices(u8, data[2..4], surface.sample(0, 1));
}

test "set_in_sample" {
    var data: [(2 * 2) * 2]u8 = undefined;
    var surface: @This() = .{
        .data = data[0..],
        .width = 2,
        .height = 2,
        .component_count = 2,
    };

    // checkerboard pattern
    var odd: bool = true;
    for (0..surface.height) |y| {
        for (0..surface.width) |x| {
            const pix = surface.sample(@intCast(x), @intCast(y));
            for (0..surface.component_count) |comp| {
                pix[comp] = if (odd) 255 else 0;
            }
            odd = !odd;
        }
    }

    try std.testing.expectEqualSlices(u8, &.{ 255, 255, 0, 0, 255, 255, 0, 0 }, data[0..]);
}
