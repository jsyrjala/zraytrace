const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vector.zig").Vec3;

pub const Texture = union (enum) {
    color: ColorTexture,
    image: ImageTexture,

    pub fn initColor(color: Color) Texture {
        return Texture{.color = ColorTexture.init(color)};
    }
    pub fn initImage(image: *Image) Texture {
        return Texture{.image = ImageTexture.init(image)};
    }
    pub fn albedo(texture: Texture, u: f32, v: f32, point :Vec3) Color {
        switch(texture) {
            Texture.color => |obj| return obj.albedo(u, v, point),
            Texture.image => |obj| return obj.albedo(u, v, point),
        }
        std.debug.warn("Texture.albedo() unreachable.", .{});
        unreachable;
    }
};

pub const ColorTexture = struct {
    color: Color,

    pub fn init(color: Color) ColorTexture {
        return ColorTexture{.color = color};
    }
    pub fn albedo(self: @This(), u: f32, v: f32, point: Vec3) Color {
        return self.color;
    }
};

pub const ImageTexture = struct {
    image: *Image,
    
    pub fn init(image: *Image) ImageTexture {
        return ImageTexture{.image = image};
    }
    pub fn albedo(self: @This(), u: f32, v: f32, point: Vec3) Color {
        const v_reversed = 1.0 - v;
        const img_x = std.math.clamp(@floatToInt(u64, u * @intToFloat(f32, self.image.width)), 0, self.image.width - 1);
        const img_y = std.math.clamp(@floatToInt(u64, v_reversed * @intToFloat(f32, self.image.height)), 0, self.image.height - 1);
        const image_offset = img_y * self.image.width + img_x;
        return self.image.pixels[image_offset];
    }
};

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const std = @import("std");
const png_image = @import("png_image.zig");

test "ColorTexture.albedo()" {
    const color = Color.init(0.1, 0.2, 0.3);
    const texture = Texture.initColor(color);
    expectEqual(color, texture.albedo(0.1, 0.1, Vec3.origin));
    expectEqual(color, texture.albedo(0.2, 0.2, Vec3.origin));
}

test "ImageTexture.albedo()" {
    const filename = "models/images/earthmap.png";
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    
    const image = try png_image.readFile(allocator, filename);

    const texture = Texture.initImage(image);
    expectEqual(Color.init(1.0e+00, 1.0e+00, 1.0e+00), texture.albedo(0.0, 0.0, Vec3.origin));
    expectEqual(Color.init(3.09803932e-01, 3.33333343e-01, 4.74509805e-01), texture.albedo(0.1, 0.1, Vec3.origin));
    expectEqual(Color.init(0.0e+00, 7.84313771e-03, 2.07843139e-01), texture.albedo(0.5, 0.5, Vec3.origin));
    expectEqual(Color.init(9.21568632e-01, 9.37254905e-01, 9.49019610e-01), texture.albedo(1.0, 1.0, Vec3.origin));
}
