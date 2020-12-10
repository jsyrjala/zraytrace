//! Byte array to store images and Color objects.
//!
const std = @import("std");
const base = @import("base.zig");
const BaseFloat = base.BaseFloat;
const Allocator = std.mem.Allocator;

/// Pixel values of 0.0 - 1.0 float
pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,

    pub const black = init(0.0, 0.0, 0.0);
    pub const white = init(1.0, 1.0, 1.0);
    pub const gold = init(1.0, 0.843, 0);
    pub const silver = init(0.752, 0.752, 0.752);
    pub const red = init(1.0, 0.01, 0.01);
    pub const green = init(0.01, 1.0, 0.01);
    pub const blue = init(0.01, 0.01, 1.0);

    // TODO why not inline allowed here?
    pub fn init(r: f32, g: f32, b: f32) Color {
        return Color{.r = r, .g = g, .b = b};
    }

    pub fn format(self: Color, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        return std.fmt.format(writer, "Color({},{},{})",
                            .{self.r, self.g, self.b});
    }

    pub inline fn elem(v: Color, index: u8) f32 {
        switch (index) {
            0 => return v.r,
            1 => return v.g,
            2 => return v.b,
            else => unreachable
        }
    }

    pub inline fn newBlack() Color {
        return init(0.0, 0.0, 0.0);
    }

    pub inline fn scale(color: Color, t: f32) Color {
        return Color.init(color.r * t, color.g * t, color.b * t);
    }

    pub inline fn multiply(color: Color, other: Color) Color {
        return Color.init(color.r * other.r, color.g * other.g, color.b * other.b);
    }

    /// Add color elements. Immutable.
    pub inline fn add(color1: Color, color2: Color) Color {
        return Color.init(color1.r + color2.r,
                            color1.g + color2.g,
                            color1.b + color2.b);
    }

    /// Add color elements. Mutable.
    pub inline fn addMutate(color: * Color, add_color: Color) void {
        color.r += add_color.r;
        color.g += add_color.g;
        color.b += add_color.b;
    }

    pub inline fn setMutate(color: * Color, set_color: Color) void {
        color.* = set_color;
    }
};

pub const Image = struct {
    allocator: *Allocator,
    width: u32,
    height: u32,
    pixels: []Color,

    pub fn init(allocator: *Allocator, width: u32, height: u32) ! *Image {
        const pixels = try allocator.alloc(Color, width * height);
        for (pixels) |*pixel, index| {
            pixel.* = Color.newBlack();
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

    pub fn format(self: Image, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        return std.fmt.format(writer, "Image({}x{})",
                            .{self.width, self.height});
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
    expectEqual(Color.newBlack(), image.pixels[0]);
    expectEqual(Color.newBlack(), image.pixels[63999]);
    expectEqual(@as(usize, 64000), image.pixels.len);
}


test "Color.init()" {
    const my_r: f32 = 0.1;
    const my_g: f32 = 0.2;
    const my_b: f32 = 0.6;
    const color = Color.init(0.1, 0.2, 0.6);
    expectEqual(my_r, color.r);
    expectEqual(my_g, color.g);
    expectEqual(my_b, color.b);

    expectEqual(my_r, color.elem(0));
    expectEqual(my_g, color.elem(1));
    expectEqual(my_b, color.elem(2));
}

test "Color.add()" {
    const color1 = Color.init(0.1, 0.2, 0.6);
    const color2 = Color.init(0.1, 0.2, 0.6);
    const black = Color.newBlack();
    const new_color1 = color2.add(black);
    expectEqual(color1, new_color1);
    const new_color2 = color2.add(color2);
    const expected = Color.init(0.2, 0.4, 1.2);
    expectEqual(expected, new_color2);
}

test "Color.addMutate()" {
    const color1 = Color.init(1., 2., 6.);
    const gray = Color.init(1., 1., 1.);
    var color2 = Color.init(1., 2., 6.);
    const black = Color.newBlack();

    Color.addMutate(&color2, black);
    expectEqual(color1, color2);

    Color.addMutate(&color2, gray);
    expectEqual(Color.init(2., 3., 7.), color2);

    // zig automatically takes a pointer to color2
    color2.addMutate(color1);
    expectEqual(Color.init(3., 5., 13.), color2);
}
