const std = @import("std");
const math = std.math;
const BaseFloat = @import("base.zig").BaseFloat;
const vector = @import("vector.zig");
const Vec3 = vector.Vec3;
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
    surface: Surface,
    pub fn init(ray: Ray, location: Vec3, outward_normal: Vec3, t: BaseFloat, surface: Surface) HitRecord {
        if (ray.direction.dot(outward_normal) > 0.0) {
            return HitRecord{.location = location,
                            .normal = outward_normal.negate(),
                            .t = t, .front_face = false,
                            .surface = surface};
        }
        return HitRecord{.location = location,
                            .normal = outward_normal,
                            .t = t, .front_face = true,
                            .surface = surface};
    }
};

//// Testing
const Sphere = @import("sphere.zig").Sphere;

test "HitRecord.init" {
    const vec = Vec3.init(1.0, 1.0, 1.0);
    const ray = Ray.init(vec, vec);
    const sphere = Sphere.init(vec, 1.0, Material.black_metal);
    const surface = Surface.init_sphere(sphere);
    const hit_record = HitRecord.init(ray, vec, vec, 1.0, surface);
}
