//! Write image in PPM format (plain)
//! http://netpbm.sourceforge.net/doc/ppm.html
const std = @import("std");
const math = std.math;
const base = @import("base.zig");
const Image = @import("image.zig").Image;
const Allocator = std.mem.Allocator;
const BaseFloat = base.BaseFloat;

/// Convert from 0.0-1.0 float to 0-255 integer
fn convertValue(value: f32) u32 {
    const v = @floatToInt(u32, value * 255.999);
    const x = math.clamp(v, @as(u32, 0), @as(u32, 255));
    return x;
}

fn writeImageData(filename: []const u8, file: std.fs.File, image: *Image) ! u32 {
    const start_time = std.time.milliTimestamp();
    var buf_stream = std.io.bufferedOutStream(file.outStream());
    const writer = buf_stream.outStream();
    const max_color = 255;
    try writer.print("P3\n", .{});
    try writer.print("# filename: {}\n", .{filename});
    // TODO there is also P6 (raw) format
    // TODO print date
    try writer.print("# The P3 = colors are in ASCII\n", .{});
    try writer.print("# Image width and height\n", .{});
    try writer.print("{} {}\n", .{image.width, image.height});
    try writer.print("# Max color value\n", .{});
    try writer.print("{}\n", .{max_color});
    try writer.print("# RGB triplets\n", .{});

    var y: usize = 0;
    while (y < image.height) : (y += 1) {
        var x: usize = 0;
        while (x < image.width) : (x += 1) {
            const pixel = image.pixels[(image.height - y - 1) * image.width + x];
            try writer.print("{d: >3} {d: >3} {d: >3}  ",
                            .{convertValue(pixel.r),
                              convertValue(pixel.g),
                              convertValue(pixel.b)});
        }
        try writer.print("\n", .{});
    }
    // need to flush here, closing file will not flush
    try buf_stream.flush();
    const end_time = std.time.milliTimestamp();
    const elapsed = @intToFloat(f32, end_time - start_time) / 1000.;
    const pixels_per_second = @intToFloat(f32, image.height * image.width) / elapsed;
    std.debug.warn("Writing took {:0.2} seconds, {:0.2} pixel/s\n", .{elapsed, pixels_per_second});
    return 0;
}

/// Write Image to File using PPM format.
pub fn writeFile(filename: []const u8, image: *Image) anyerror! void {
    // TODO add .write = true to props?
    std.debug.warn("Writing {} pixels to file {}\n",
                    .{image.width * image.height, filename});

    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    const bytes_written = try writeImageData(filename, file, image);
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
    try writeFile(filename, image);

    const file = try std.fs.cwd().openFile(filename, .{.read = true});
    const stat = try file.stat();
    expectEqual(@as(u64, 1446), stat.size);
}
