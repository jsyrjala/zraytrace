const base = @import("base.zig");
const vector = @import("vector.zig");
const BaseFloat = base.BaseFloat;
const Vec3 = vector.Vec3;

/// Model a single ray
pub const Ray = struct {
    origin: Vec3,
    direction: Vec3,

    pub inline fn init(origin: Vec3, direction: Vec3) Ray {
        return Ray{.origin = origin, .direction = direction.unitVector()};
    }
    pub inline fn rayAt(ray: Ray, t: BaseFloat) Vec3 {
        return ray.origin.plus(ray.direction.scale(t));
    }

    pub fn format(self: Ray, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        return std.fmt.format(writer, "Ray(Origin({},{},{}),Direction({},{},{}))",
                            .{self.origin.x(), self.origin.y(), self.origin.z(),
                              self.direction.x(), self.direction.y(), self.direction.z(),});
    }
};

//// Testing
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Ray.rayAt" {
    const origin = Vec3.init(1.0, 1.0, 1.0);
    const direction = Vec3.init(1.0, 2.0, 3.0);
    const ray = Ray.init(origin, direction);
    const vec = ray.rayAt(2.0);
    const expected = Vec3.init(1.53452253e+00, 2.06904506e+00, 2.60356736e+00);
    expectEqual(expected, vec);
}
