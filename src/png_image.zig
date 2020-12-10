const std = @import("std");
const Allocator = std.mem.Allocator;
const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;

const c = @cImport({
    @cInclude("png.h");
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});



const PngError = error {
    BadPngFile,
    FailedToOpenFile,
    UnsupportedPngFeature,
};

/// Read PNG file. Supports only 8 bit RGB format.
/// https://gist.github.com/niw/5963798
pub fn readFile(allocator: *Allocator, filename: []const u8) anyerror! *Image {
    var png: c.png_structp = c.png_create_read_struct(c.PNG_LIBPNG_VER_STRING, null, null, null);
    if (png == null) {
        return PngError.BadPngFile;
    }
    
    var info: c.png_infop = c.png_create_info_struct(png);
    if (info == null) {
        return PngError.BadPngFile;
    }

    const fp = c.fopen(@ptrCast([*c]const u8, filename), "rb");
    if (fp == null) {
        std.debug.warn("Can't open file {}", .{filename});
        return PngError.FailedToOpenFile;
    }

    c.png_init_io(png, fp);
    c.png_read_info(png, info);
    const width = c.png_get_image_width(png, info);
    const height = c.png_get_image_height(png, info);
    const color_type = c.png_get_color_type(png, info);
    const bit_depth  = c.png_get_bit_depth(png, info);

    std.debug.warn("PNG data {} {}x{} color_type={} bits={}\n", .{filename, width, height, color_type, bit_depth});
    if (color_type != c.PNG_COLOR_TYPE_RGB) {
        std.debug.warn("Unsupported color type {}", .{color_type});
        return PngError.UnsupportedPngFeature;
    }
    if (bit_depth != 8) {
        std.debug.warn("Unsupported bit depth {}", .{bit_depth});
        return PngError.UnsupportedPngFeature;
    }

    // add empty alpha channel
    // https://refspecs.linuxbase.org/LSB_3.1.0/LSB-Desktop-generic/LSB-Desktop-generic/libpng12.png.get.valid.1.html
    // https://refspecs.linuxbase.org/LSB_4.0.0/LSB-Desktop-generic/LSB-Desktop-generic/libpng12.png.set.trns.to.alpha.1.html
    // if(c.png_get_valid(png, info, c.PNG_INFO_tRNS) != 0) {
    //    c.png_set_tRNS_to_alpha(png);
    //}
    // c.png_set_filler(png, 0xFF, PNG_FILLER_AFTER);

    c.png_read_update_info(png, info);

    // Reading pixels
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const tmp_allocator = &arena.allocator;

    var row_pointers: [*c][*c]c.png_byte = @ptrCast([*c][*c]c.png_byte, @alignCast(8, try tmp_allocator.alloc(c.png_bytep, height)));
    var y: u16 = 0;
    while (y < height) : (y += 1) {
        const byte_count = c.png_get_rowbytes(png, info);
        row_pointers[y] = @ptrCast([*c]c.png_byte, @alignCast(8, try tmp_allocator.alloc(c.png_bytep, byte_count)));
    }

    c.png_read_image(png, row_pointers);
    const image = try Image.init(allocator, width, height);
    y = 0;
    while (y < height) : (y += 1) {
        const row: c.png_bytep = row_pointers[y];
        var x: u16 = 0;
        while (x < width) : (x += 1) {
            const px0: c.png_byte = row[x * 3 + 0];
            const px1: c.png_byte = row[x * 3 + 1];
            const px2: c.png_byte = row[x * 3 + 2];
            // TODO Image flipped around X axis
            const image_offset = (height - y - 1) * height + x;
            image.pixels[image_offset] = Color.init(@intToFloat(f32, px0)/0xff, @intToFloat(f32, px1)/0xff, @intToFloat(f32, px2)/0xff);
        }
    }

    _ = c.fclose(fp);
    c.png_destroy_read_struct(&png, &info, null);
    return image;
}

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const ppm_image = @import("ppm_image.zig");

test "read png" {
    const filename = "models/images/nitor-logo.png";
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    
    const image: * Image = try readFile(allocator, filename);
    defer image.deinit();
    try ppm_image.writeFile("target/nitor-logo.ppm", image);

}