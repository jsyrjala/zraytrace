const std = @import("std");
const math = std.math;
const Vec3 = @import("vector.zig").Vec3;
const BaseFloat = @import("base.zig").BaseFloat;
const Ray = @import("ray.zig").Ray;

fn deg2rad(deg: f32) f32 {
    return math.pi * deg / 180.0;
}

pub const Camera = struct {
    origin: Vec3,
    lower_left_corner: Vec3,
    horizontal: Vec3,
    vertical: Vec3,

    pub fn init(look_from: Vec3, look_at: Vec3, vup: Vec3,
                vfov: f32, aspect_ratio: f32) Camera {
        const theta = deg2rad(vfov);
        const h = math.tan(theta / 2.0);
        const viewport_height = 2.0 * h;
        const viewport_width = aspect_ratio * viewport_height;
        const w = look_from.minus(look_at).unitVector();
        const u = vup.cross(w).unitVector();
        const v = w.cross(u);
        const horizontal = u.scale(viewport_width);
        const vertical = v.scale(viewport_height);
        const lower_left_corner = look_from.minus(horizontal.scale(1/2.0))
                                            .minus(vertical.scale(1/2.0))
                                            .minus(w);
        std.debug.assert(!math.isNan(w.x()));
        std.debug.assert(!math.isNan(u.x()));
        return Camera{.origin = look_from, .lower_left_corner = lower_left_corner,
                        .horizontal = horizontal, .vertical = vertical};
    }

    pub fn format(self: Camera, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        return std.fmt.format(writer, "Camera(Origin({},{},{}),Horizontal({},{},{}),Vertical({},{},{}))",
                            .{self.origin.x(), self.origin.x(), self.origin.x(),
                              self.horizontal.x(), self.horizontal.x(), self.horizontal.x(),
                              self.vertical.x(), self.vertical.x(), self.vertical.x(),});
    }

    pub fn getRay(camera: Camera, u: BaseFloat, v: BaseFloat) Ray {
        const dir = camera.lower_left_corner
                    .plus(camera.horizontal.scale(u))
                    .plus(camera.vertical.scale(v))
                    .minus(camera.origin);
        return Ray.init(camera.origin, dir);
    }
};


//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
test "Camera.init()" {
    const look_from = Vec3.init(1.0, 0, 0);
    const look_at = Vec3.init(0.0, 0, 1.0);
    const vup = Vec3.init(0.0, 1.0, 0.0);
    const camera = Camera.init(look_from, look_at, vup, 45.0, 1.0);
    // TODO better test
    expectEqual(look_from, camera.origin);
}

test "Camera.getRay()" {
    const look_from = Vec3.init(1.0, 0, 0);
    const look_at = Vec3.init(0.0, 0, 1.0);
    const vup = Vec3.init(0.0, 1.0, 0.0);
    const camera = Camera.init(look_from, look_at, vup, 45.0, 1.0);
    const ray = camera.getRay(1.0, 1.0);
    const expected = Ray.init(look_from, look_at);
    expectEqual(expected.origin, ray.origin);
    // expectEqual(expected.direction, ray.direction);
}
