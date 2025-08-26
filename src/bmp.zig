const std = @import("std");
const Surface = @import("Surface.zig");

pub const FileHeader = extern struct {
    magic: [2]u8 = .{ 0x42, 0x4D },
    file_size: u32 align(1),
    reserved0_: u32 align(1) = 0,
    pixel_data_offset: u32 align(1),
};

pub const CompressionMethod = enum(u32) {
    rgb = 0,
    rle8 = 1,
    rle4 = 2,
    bitfields = 3,
    jpeg = 4,
    png = 5,
    alphabitfields = 6,
    cmyk = 11,
    _,
};

pub const BitmapInfoHeader = extern struct {
    header_size: u32 = 40,
    width: i32,
    height: i32,
    plane_count: u16 align(1) = 1,

    /// bits used per pixel (for all components)
    bits_per_pixel: u16 align(1),
    compression: CompressionMethod,

    /// Size of the pixel data when decompressed (including padding)
    image_size: u32,
    hor_pixel_per_metre: i32 = 2835,
    ver_pixel_per_metre: i32 = 2835,
    pallete_color_count: u32 = 0,
    important_colors: u32 = 0,
};

pub fn saveSurface(writer: std.io.AnyWriter, surface: *const Surface) anyerror!void {
    switch (surface.format) {
        .bgr8 => {}, // TODO: support bgra8
        else => return error.Unsupported,
    }

    var file_header: FileHeader = .{
        .file_size = @sizeOf(FileHeader) + @sizeOf(BitmapInfoHeader),
        .pixel_data_offset = 0,
    };

    const bpp = 24;

    // size including padding
    const scanline_size = ((bpp * surface.width + 31) / 32) * 4;
    const info_header: BitmapInfoHeader = .{
        .width = @intCast(surface.width),
        .height = @intCast(surface.height),
        .bits_per_pixel = bpp,
        .compression = .rgb,
        .image_size = surface.height * scanline_size,
    };
    file_header.pixel_data_offset = std.mem.alignForward(u32, file_header.file_size, 32);

    const gap1_size = file_header.pixel_data_offset - file_header.file_size;
    file_header.file_size = file_header.pixel_data_offset + info_header.image_size;

    try writer.writeStructEndian(file_header, .little);
    try writer.writeStructEndian(info_header, .little);
    try writer.writeByteNTimes(0, gap1_size);

    for (0..surface.height) |y| {
        for (0..surface.width) |x| {
            const sample = surface.sample(@intCast(x), @intCast(surface.height + @as(isize, @bitCast(~y))));
            try writer.writeByte(sample[0]);
            try writer.writeByte(sample[1]);
            try writer.writeByte(sample[2]);
        }
        try writer.writeByteNTimes(0, scanline_size - (bpp * surface.width / 8));
    }
}
