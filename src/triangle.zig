const std = @import("std");
const math = std.math;
const BaseFloat = @import("base.zig").BaseFloat;
const vector = @import("vector.zig");
const Vec3 = vector.Vec3;
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("hit_record.zig").HitRecord;
const Surface = @import("surface.zig").Surface;
const Color = @import("image.zig").Color;
const Material = @import("material.zig").Material;
const AABB = @import("aabb.zig").AABB;

/// Surface with 3 vertexes
pub const Triangle = struct {
    // TODO use some generics trick
    /// Triangle vertices
    a: Vec3,
    b: Vec3,
    c: Vec3,
    /// two side edges of triangle
    e1: Vec3,
    e2: Vec3,
    /// Face normal
    face_normal: Vec3,
    /// Face normal in unit length
    face_unit_normal: Vec3,
    material: *const Material,
    /// Axis aligned bounding box
    aabb: AABB,

    pub fn init(a: Vec3, b: Vec3, c: Vec3, material: *const Material) Triangle {
        const aabb = AABB.initAabb(AABB.initMinMax(a,b), AABB.initMinMax(a,c));
        const e1 = b.minus(a);
        const e2 = c.minus(a);
        const face_normal = e1.cross(e2);
        const face_unit_normal = face_normal.unitVector();
        return Triangle{.a = a, .b=b, .c = c,
                        .face_normal = face_normal,
                        .face_unit_normal = face_unit_normal,
                        .e1 = e1, .e2 = e2,
                        .material = material,
                        .aabb = aabb};
    }

    /// Detect if a ray hits the triangle
    /// https://stackoverflow.com/questions/42740765/intersection-between-line-and-triangle-in-3d
    pub fn hit(triangle: Triangle, surface: Surface, ray: Ray, t_min: BaseFloat, t_max: BaseFloat) ? HitRecord{
        const a = triangle.a;
        const b = triangle.b;
        const c = triangle.c;
        const e1 = triangle.e1;
        const e2 = triangle.e2;
        const det = -ray.direction.dot(triangle.face_normal);
        const inv_det = 1.0 / det;
        const ao = ray.origin.minus(a);
        const dao = ao.cross(ray.direction);
        const u = e2.dot(dao) * inv_det;
        const v = -e1.dot(dao) * inv_det;
        const t = ao.dot(triangle.face_normal) * inv_det;
        const is_hit = det >= 1e-6 and t > t_min and t < t_max and
                        u >= 0.0 and v >= 0.0 and (u+v) <= 1.0;
        if (is_hit) {
            const location = ray.origin.plus(ray.direction.scale(t));
            return HitRecord.init(ray, location, triangle.face_unit_normal, t, surface);
        }
        return null;
    }
};

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Triangle.init()" {
    const a = Vec3.init(1.0, 0.0, 0.0);
    const b = Vec3.init(0.0, 1.0, 0.0);
    const c = Vec3.init(0.0, 0.0, 1.0);
    const triangle = Triangle.init(a, b, c, &Material.black_metal);
}

test "Triangle.hit() ray doesn't hit the triangle" {
    const a = Vec3.init(1.0, 0.0, 0.0);
    const b = Vec3.init(0.0, 1.0, 0.0);
    const c = Vec3.init(0.0, 0.0, 1.0);
    const triangle = Triangle.init(a, b, c, &Material.black_metal);
    const surface = Surface.initTriangle(triangle);
    const vec = Vec3.init(1.0, 1.0, 1.0);
    const ray = Ray.init(vec, vec);
    const hit_record = triangle.hit(surface, ray, 0.1, 10000.0);
    if (hit_record != null ) {
        expect(false);
    }
}

test "Triangle.hit() ray hits the triangle" {
    const a = Vec3.init(10., 5., 1.0);
    const b = Vec3.init(-10.0, -10.0, 1.0);
    const c = Vec3.init(-10.0, 10.0, 1.0);
    const triangle = Triangle.init(a, b, c, &Material.black_metal);
    const surface = Surface.initTriangle(triangle);

    const origin = Vec3.init(0.0, 0.0, -10.0);
    const direction = Vec3.init(0.0, 0.0, 1.0);
    const ray = Ray.init(origin, direction);
    const hit_record = triangle.hit(surface, ray, 0.1, 10000.0);
    if (hit_record == null) {
        expect(false);
    } else {
        const hit = hit_record.?;
        expectEqual(Vec3.init(0.0, 0.0, 1.0), hit.location);
        expectEqual(Vec3.init(0.0, 0.0, -1.0), hit.normal);
        expectEqual(@as(BaseFloat, 11.0), hit.t);
        expectEqual(true, hit.front_face);
    }
}
