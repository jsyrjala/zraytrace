const std = @import("std");
const math = std.math;
const BaseFloat = @import("base.zig").BaseFloat;
const vector = @import("vector.zig");
const Vec3 = vector.Vec3;
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("hit_record.zig").HitRecord;
const Metal = @import("material.zig").Metal;
const Color = @import("image.zig").Color;
 
pub const Sphere = struct {
    center: Vec3,
    radius: BaseFloat,
    material: Metal,

    pub fn init(center: Vec3, radius: BaseFloat, material: Metal) Sphere {
        return Sphere{.center = center, .radius = radius,
                    .material = material};
    }

    pub fn hit(sphere:Sphere, ray:Ray, t_min: BaseFloat, t_max: BaseFloat) ? HitRecord {
        const oc = ray.origin.minus(sphere.center);
        const a = ray.direction.length_squared();
        const half_b = oc.dot(ray.direction);
        const c = oc.length_squared() - (sphere.radius * sphere.radius);
        const discriminant = half_b*half_b - a*c;

        if (discriminant > 0) {
            const root = math.sqrt(discriminant);
            // handle two halves of quadratic solution
            const t1 = (-half_b - root) / a;
            if (t1 < t_max and t1 > t_min) {
                const location = ray.ray_at(t1);
                const outward_normal = location.minus(sphere.center).scale(1./sphere.radius);
                return HitRecord.init(ray, location, outward_normal, t1, sphere);
            }
            // this should happen only if ray starting point is inside of the sphere?
            const t2 = (-half_b + root) / a;
            if (t2 < t_max and t2 > t_min) {
                const location = ray.ray_at(t2);
                const outward_normal = location.minus(sphere.center).scale(1./sphere.radius);
                return HitRecord.init(ray, location, outward_normal, t2, sphere);
            }
        }
        // the ray did not hit the sphere
        return null;
    }
};

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Sphere.init" {
    const material = Metal.init(Color.black);
    const vec = Vec3.init(1.0, 1.0, 1.0);
    const sphere = Sphere.init(vec, 10.0, material);

    const ray = Ray.init(vec, vec);
    const hit_record = sphere.hit(ray, 0.1, 10000.0);
}
