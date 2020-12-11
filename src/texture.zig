const std = @import("std");
const math = std.math;
const Random = std.rand.Random;

const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vector.zig").Vec3;
const Vec2 = @import("vector.zig").Vec2;

pub const Texture = union (enum) {
    color: ColorTexture,
    image: ImageTexture,
    perlin: PerlinTexture,

    pub fn initColor(color: Color) Texture {
        return Texture{.color = ColorTexture.init(color)};
    }
    pub fn initImage(image: *Image) Texture {
        return Texture{.image = ImageTexture.init(image, 0.19, 0.1)};
    }
    pub fn initImageOpts(image: *Image, u_offset: f32, v_offset: f32) Texture {
        return Texture{.image = ImageTexture.init(image, u_offset, v_offset)};
    }
    pub fn initPerlin(random, color: Color) Texture {
        return Texture{.perlin = PerlinTexture.init(color)};
    }

    pub fn albedo(texture: Texture, texture_coords: Vec2, point :Vec3) Color {
        switch(texture) {
            Texture.color => |obj| return obj.albedo(texture_coords, point),
            Texture.image => |obj| return obj.albedo(texture_coords, point),
            Texture.perlin => |obj| return obj.albedo(texture_coords, point),
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


pub const PerlinTexture = struct {
    scale: f32,
    color: Color,

    pub fn init(color: Color) PerlinTexture {
        return PerlinTexture{.color = color, .scale = 0.5};
    }

    pub fn albedo(self: @This(), texture_coords: Vec2, point: Vec3) Color {
        return self.color.scale(self.turbulence(point.scale(self.scale), 7));
    }

    fn turbulence(self: @This(), point: Vec3, depth: u32) f32 {
        var accum: f32 = 0.0;
        var temp_p = point;
        var weight: f32 = 0.5;

        var i: usize = 0;
        while (i < depth) : (i += 1) {
            accum = weight * self.noise(temp_p);
            weight *= 0.5;
            temp_p = temp_p.scale(2.0);
        }
        return math.absFloat(accum);
    }

    fn noise(self: @This(), p: Vec3) f32 {
        const u = p.x() - math.floor(p.x());
        const v = p.y() - math.floor(p.z());
        const w = p.z() - math.floor(p.z());
        const i = @floatToInt(i32, math.floor(p.x()));
        const j = @floatToInt(i32, math.floor(p.y()));
        const k = @floatToInt(i32, math.floor(p.z()));

        var c: [2][2][2]Vec3 = [2][2][2]Vec3{
            [_][2]Vec3{
                [_]Vec3{Vec3.origin, Vec3.origin},
                [_]Vec3{Vec3.origin, Vec3.origin},
            },
            [_][2]Vec3{
                [_]Vec3{Vec3.origin, Vec3.origin},
                [_]Vec3{Vec3.origin, Vec3.origin},
            },
        };

        var di: u16 = 0;
        while (di < 2) : (di += 1) {
            var dj: u16 = 0;
            while (dj < 2) : (dj += 1) {
                var dk: u16 = 0;
                while (dk < 2) : (dk += 1) {
                    c[di][dj][dk] = Vec3.x_unit;
                }
            }
        }
        return interpolate(c, u, v, w);
    }

    fn interpolate(c: [2][2][2]Vec3, u: f32, v: f32, w: f32) f32 {
        const uu = u*u*(3-2*u);
        const vv = v*v*(3-2*v);
        const ww = w*w*(3-2*w);
        var accum: f32 = 0;

        var i: u16 = 0;
        while (i < 2) : (i += 1) {
            var j: u16 = 0;
            while (j < 2) : (j += 1) {
                var k: u16 = 0;
                while (k < 2) : (k += 1) {
                    const i_f = @intToFloat(f32, i);
                    const j_f = @intToFloat(f32, j);
                    const k_f = @intToFloat(f32, k);
                    const weight_v = Vec3.init(u - i_f, v - j_f, w - k_f);
                    const x = (i_f * uu + (1.0 - i_f) * (1.0 - uu))
                            * (j_f * vv + (1.0 - j_f) * (1.0 - vv))
                            * (k_f * ww + (1.0 - k_f) * (1.0 - ww));
                    accum += c[i][j][k].dot(weight_v) * x;
                }
            }
        }
        return accum;
    }
};

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
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

test "PerlinTexture.albedo()" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    const perlin = PerlinTexture.init(Color.blue);
    
    const x = perlin.albedo(Vec2.init(0.1, 0.1), Vec3.origin);
    std.debug.warn("x={}", .{x});

    
}