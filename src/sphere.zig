const std = @import("std");
const math = std.math;
const BaseFloat = @import("base.zig").BaseFloat;
const vector = @import("vector.zig");
const Vec3 = vector.Vec3;
const Vec2 = vector.Vec2;
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("hit_record.zig").HitRecord;
const Material = @import("material.zig").Material;
const Color = @import("image.zig").Color;
const Surface = @import("surface.zig").Surface;
const AABB = @import("aabb.zig").AABB;

/// Sphere or a ball
pub const Sphere = struct {
    center: Vec3,
    radius: BaseFloat,
    material: *const Material,
    /// Axis aligned bounding box
    aabb: AABB,

    pub const unit_sphere = init(Vec3.origin, 1.0, Material.black_metal);

    pub fn init(center: Vec3, radius: BaseFloat, material: *const Material) Sphere {
        const aabb = AABB.initMinMax(center.minus(Vec3.init(radius, radius, radius)),
                                     center.plus(Vec3.init(radius, radius, radius)));
        return Sphere{.center = center, .radius = radius,
                      .material = material, .aabb = aabb};
    }

    pub fn hit(sphere: Sphere, surface: Surface, ray: *const Ray, t_min: BaseFloat, t_max: BaseFloat) ? HitRecord {
        const oc = ray.origin.minus(sphere.center);
        const half_b = oc.dot(ray.direction);
        const c = oc.lengthSquared() - (sphere.radius * sphere.radius);
        const discriminant = half_b*half_b - c;
        if (discriminant < 0) {
            // the ray did not hit the sphere
            return null;
        }
        const root = math.sqrt(discriminant);
        // handle two halves of quadratic solution
        const t1 = -half_b - root;
        if (t1 < t_max and t1 > t_min) {
            const location = ray.rayAt(t1);
            const outward_normal = location.minus(sphere.center).scale(1./sphere.radius);
            // TODO texture coordinates
            const theta = std.math.acos(-outward_normal.y());
            const phi = std.math.atan2(BaseFloat, - outward_normal.z(), - outward_normal.x()) + std.math.pi;
            const u = phi / (2 * std.math.pi);
            const v = theta / std.math.pi;
            const texture_coords = Vec2.init(u, v);

            return HitRecord.init(ray, location, outward_normal, t1, surface, texture_coords);
        }
        // this should happen only if ray starting point is inside of the sphere?
        const t2 = -half_b + root;
        if (t2 < t_max and t2 > t_min) {
            const location = ray.rayAt(t2);
            const outward_normal = location.minus(sphere.center).scale(1./sphere.radius);
            // TODO texture coordinates
            const theta = std.math.acos(-outward_normal.y());
            const phi = std.math.atan2(BaseFloat, - outward_normal.z(), - outward_normal.x()) + std.math.pi;
            const u = phi / (2 * std.math.pi);
            const v = theta / std.math.pi;
            const texture_coords = Vec2.init(u, v);

            return HitRecord.init(ray, location, outward_normal, t2, surface, texture_coords);
        }
        // no hit inside t_min/t_max
        return null;
    }
};

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Sphere.init" {
    const vec = Vec3.init(1.0, 1.0, 1.0);
    const sphere = Sphere.init(vec, 10.0, &Material.black_metal);
    const surface = Surface.initSphere(sphere);
    const ray = Ray.init(vec, vec);
    const hit_record = sphere.hit(surface, ray, 0.1, 10000.0);
}
