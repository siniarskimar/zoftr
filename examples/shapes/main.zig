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

    const a: [2]u32 = .{ 0, 0 };
    const b: [2]u32 = .{ surface.width, 0 };
    const c: [2]u32 = .{ 0, surface.height };

    surface.clear();
    surface.drawTriangle(.{
        a,
        b,
        c,
    });

    {
        const file = try std.fs.cwd().createFile("rect.bmp", .{});
        defer file.close();

        var buff_writer = std.io.bufferedWriter(file.writer());
        defer buff_writer.flush() catch |err| {
            std.log.err("failed to flush BMP stream: {}", .{err});
        };
        try bmp.saveSurface(buff_writer.writer().any(), &surface);
    }
}
