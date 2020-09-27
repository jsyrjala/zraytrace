const std = @import("std");
const base = @import("base.zig");
const BaseFloat = base.BaseFloat;
const Allocator = std.mem.Allocator;

/// Pixel values of 0.0 - 1.0 float
pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    pub inline fn black() Color {
        return Color{.r = 0., .g = 0., .b = 0.};
    }
};

pub const Image = struct {
    allocator: *Allocator,
    width: u16,
    height: u16,
    pixels: []Color,

    pub fn init(allocator: *Allocator, width: u16, height: u16) ! *Image {
        const pixels = try allocator.alloc(Color, width * height);
        for (pixels) |*pixel, index| {
            pixel.* = Color.black();
        }
        const image = try allocator.create(Image);
        image.* = Image{.allocator = allocator,
                    .width = width, .height = height,
                    .pixels = pixels};
        return image;
    }

    pub fn deinit(image: *const Image) void {
        image.allocator.free(image.pixels);
        image.allocator.destroy(image);
    }
};


//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Image" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const image = try Image.init(allocator, 320, 200);
    defer image.deinit();

    const color = image.pixels[1];
    expectEqual(Color.black(), image.pixels[0]);
    expectEqual(Color.black(), image.pixels[63999]);
    expectEqual(@as(usize, 64000), image.pixels.len);
}
