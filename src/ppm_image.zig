//! Write image in PPM format (plain)
//! http://netpbm.sourceforge.net/doc/ppm.html
const std = @import("std");
const math = std.math;
const base = @import("base.zig");
const Image = @import("image.zig").Image;
const Allocator = std.mem.Allocator;
const BaseFloat = base.BaseFloat;

fn limit_color(value: f32, max_color: u32) u32 {
    const v = @floatToInt(u32, 255.999 * value * @intToFloat(f32, max_color));
    return math.clamp(v, 0, max_color);
}

fn write_image_data(filename: []const u8, file: std.fs.File, image: *Image) ! u32 {
    const writer = file.outStream();
    const max_color = 255;
    try file.writeAll("P3\n");
    try writer.print("# filename: {}\n", .{filename});
    // TODO there is also P6 (raw) format
    // TODO print date
    try file.writeAll("# The P3 = colors are in ASCII\n");
    try file.writeAll("# Image width and height\n");
    try writer.print("{} {}\n", .{image.width, image.height});
    try file.writeAll("# Max color value\n");
    try writer.print("{}\n", .{max_color});
    try file.writeAll("# RGB triplets\n");

    var y: usize = 0;
    while (y < image.height) : (y += 1) {
        var x: usize = 0;
        while (x < image.height) : (x += 1) {
            const pixel = image.pixels[y * image.width + x];
            try writer.print("{d: >3} {d: >3} {d: >3}  ",
                            .{limit_color(pixel.r, max_color),
                                limit_color(pixel.g, max_color),
                                limit_color(pixel.b, max_color)});
        }
        try writer.print("\n", .{});
    }
    return 0;
}

pub fn write_file(filename: []const u8, image: *Image) anyerror! void {
    // TODO add .write = true to props?
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    const bytes_written = try write_image_data(filename, file, image);
    std.debug.warn("Wrote {} bytes to file {}\n", .{bytes_written, filename});
}

//// Testing
const expectEqual = std.testing.expectEqual;

test "write PPM image" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const image = try Image.init(allocator, 10, 10);
    defer image.deinit();
    const filename = "./target/img-file.ppm";
    try write_file(filename, image);

    const file = try std.fs.cwd().openFile(filename, .{.read = true});
    const stat = try file.stat();
    expectEqual(@as(u64, 1446), stat.size);
}
