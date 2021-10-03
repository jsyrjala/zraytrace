//! HitRecord contains information about ray hitting
//! a Surface.

const std = @import("std");
const math = std.math;
const BaseFloat = @import("base.zig").BaseFloat;
const vector = @import("vector.zig");
const Vec3 = vector.Vec3;
const Vec2 = vector.Vec2;
const Ray = @import("ray.zig").Ray;
const Surface = @import("surface.zig").Surface;
const Material = @import("material.zig").Material;

pub const HitRecord = struct {
    /// Location of collision
    location: Vec3,
    /// Object normal at collision, pointing against the ray
    normal: Vec3,
    /// t parameter at collion
    t: BaseFloat,
    /// True if ray hit front side of the surface
    front_face: bool,
    /// Pointer to object that collided
    surface: *const Surface,
    /// Texture coordinates
    texture_coords: Vec2,
    
    pub fn init(ray: *const Ray, location: Vec3, outward_normal: Vec3, t: BaseFloat, surface: *const Surface, texture_coords: Vec2) HitRecord {
        if (ray.direction.dot(outward_normal) > 0.0) {
            return HitRecord{.location = location,
                            .normal = outward_normal.negate(),
                            .t = t, .front_face = false,
                            .surface = surface, 
                            .texture_coords = texture_coords};
        }
        return HitRecord{.location = location,
                            .normal = outward_normal,
                            .t = t, .front_face = true,
                            .surface = surface,
                            .texture_coords = texture_coords};
    }

    pub fn format(self: HitRecord, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        return std.fmt.format(writer, "HitRecord(Location({},{},{}),Normal({},{},{}),t={},front_face={})",
                            .{self.location.x(), self.location.y(), location.z(),
                              self.normal.x(), self.normal.y(), normal.z(),
                              self.t, self.front_face});
    }
};

//// Testing
const Sphere = @import("sphere.zig").Sphere;

test "HitRecord.init" {
    const vec = Vec3.init(1.0, 1.0, 1.0);
    const ray = Ray.init(vec, vec);
    const sphere = Sphere.init(vec, 1.0, &Material.black_metal);
    const surface = Surface.initSphere(sphere);
    const hit_record = HitRecord.init(&ray, vec, vec, 1.0, &surface, Vec2.origin);
}
