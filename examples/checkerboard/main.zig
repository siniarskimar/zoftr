const std = @import("std");
const zoftr = @import("zoftr");
const bmp = zoftr.bmp;

pub fn main() !void {
    var data: [256 * 256 * 3]u8 = undefined;

    var surface = zoftr.Surface{
        .data = data[0..],
        .width = 64,
        .height = 64,
        .format = .bgr8,
    };

    const rect_size: usize = 8;

    for (0..surface.height) |y| {
        for (0..surface.width) |x| {
            const odd = (y / rect_size + x / rect_size) % 2 == 0;
            const pixel = surface.sample(@intCast(x), @intCast(y));
            pixel[0..3].* = @splat(if (odd) 255 else 128);
        }
    }

    {
        const checkerboard_bmp = try std.fs.cwd().createFile("checkerboard.bmp", .{});
        defer checkerboard_bmp.close();

        var buff_writer = std.io.bufferedWriter(checkerboard_bmp.writer());
        defer buff_writer.flush() catch |err| {
            std.log.err("failed to flush BMP stream: {}", .{err});
        };
        try bmp.saveSurface(buff_writer.writer().any(), &surface);
    }
}
