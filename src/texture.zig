const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vector.zig").Vec3;
const Vec2 = @import("vector.zig").Vec2;

pub const Texture = union (enum) {
    color: ColorTexture,
    image: ImageTexture,

    pub fn initColor(color: Color) Texture {
        return Texture{.color = ColorTexture.init(color)};
    }
    pub fn initImage(image: *Image) Texture {
        return Texture{.image = ImageTexture.init(image, 0.19, 0.1)};
    }
    pub fn initImageOpts(image: *Image, u_offset: f32, v_offset: f32) Texture {
        return Texture{.image = ImageTexture.init(image, u_offset, v_offset)};
    }
    pub fn albedo(texture: Texture, texture_coords: Vec2, point :Vec3) Color {
        switch(texture) {
            Texture.color => |obj| return obj.albedo(texture_coords, point),
            Texture.image => |obj| return obj.albedo(texture_coords, point),
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
    pub fn albedo(self: @This(), texture_coords: Vec2, point: Vec3) Color {
        _ = texture_coords;
        _ = point;
        return self.color;
    }
};

pub const ImageTexture = struct {
    image: *Image,
    u_offset: f32,
    v_offset: f32,

    pub fn init(image: *Image, u_offset: f32, v_offset: f32) ImageTexture {
        return ImageTexture{.image = image, .u_offset = u_offset, .v_offset = v_offset};
    }

    pub fn albedo(self: @This(), texture_coords: Vec2, point: Vec3) Color {
        const uu_first = (1.0 - texture_coords.u + self.u_offset);
        var uu = uu_first;
        if (uu_first > 1.0) {
            uu = uu_first - 1.0;
        } else if (uu_first < 0) {
            uu = uu_first + 1.0;
        }

        const v_offset = 0.1;
        const vv_first = texture_coords.v + self.v_offset;
        var vv = vv_first;
        if (vv_first > 1.0) {
            vv = vv_first - 1.0;
        } else if (uu_first < 0) {
            vv = vv_first + 1.0;
        }

        const img_x = std.math.clamp(@floatToInt(u64, uu * @intToFloat(f32, self.image.width)), 0, self.image.width - 1);
        const img_y = std.math.clamp(@floatToInt(u64, vv * @intToFloat(f32, self.image.height)), 0, self.image.height - 1);
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
    expectEqual(color, texture.albedo(Vec2.init(0.1, 0.1), Vec3.origin));
    expectEqual(color, texture.albedo(Vec2.init(0.2, 0.2), Vec3.origin));
}

test "ImageTexture.albedo()" {
    const filename = "models/images/earthmap.png";
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    
    const image = try png_image.readFile(allocator, filename);

    const texture = Texture.initImageOpts(image, 0, 0);
    expectEqual(Color.init(9.21568632e-01,9.37254905e-01,9.49019610e-01), texture.albedo(Vec2.init(0.0, 0.0), Vec3.origin));
    expectEqual(Color.init(9.25490200e-01,9.45098042e-01,9.56862747e-01), texture.albedo(Vec2.init(0.1, 0.1), Vec3.origin));
    expectEqual(Color.init(0.0e+00, 7.84313771e-03, 2.07843139e-01), texture.albedo(Vec2.init(0.5, 0.5), Vec3.origin));
    expectEqual(Color.init(1.0e+00,1.0e+00,1.0e+00), texture.albedo(Vec2.init(1.0, 1.0), Vec3.origin));
}
