//! Axis Aligned Bounding Box
const std = @import("std");
const BaseFloat = @import("base.zig").BaseFloat;
const Vec3 = @import("vector.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const ArrayList = std.ArrayList;
const math = std.math;

pub const AABB = struct {
    min: Vec3,
    max: Vec3,

    /// Return a vector that contains minimum coordinates
    fn minimum_vec(vec1: Vec3, vec2: Vec3) Vec3 {
        return Vec3.init(math.min(vec1.x(), vec2.x()),
                        math.min(vec1.y(), vec2.y()),
                        math.min(vec1.z(), vec2.z()));
    }

    /// Return a vector that contains maximum coordinates
    fn maximum_vec(vec1: Vec3, vec2: Vec3) Vec3 {
        return Vec3.init(math.max(vec1.x(), vec2.x()),
                        math.max(vec1.y(), vec2.y()),
                        math.max(vec1.z(), vec2.z()));
    }

    /// Create AABB from two vertices
    pub fn init_min_max(corner1: Vec3, corner2: Vec3) AABB {
        return AABB{.min = minimum_vec(corner1, corner2),
                    .max = maximum_vec(corner1, corner2)};
    }

    /// Create AABB from list of vertices
    pub fn init_vertexes(vertexes: ArrayList(Vec3)) AABB {
        // TODO what if there is 0 or 1 vertexes?
        std.debug.assert(vertexes.items.len > 1);
        var min_x = math.inf(BaseFloat);
        var min_y = math.inf(BaseFloat);
        var min_z = math.inf(BaseFloat);

        var max_x = -math.inf(BaseFloat);
        var max_y = -math.inf(BaseFloat);
        var max_z = -math.inf(BaseFloat);

        for (vertexes.items) |*vertex, i| {
            min_x = math.min(min_x, vertex.x());
            min_y = math.min(min_y, vertex.y());
            min_z = math.min(min_z, vertex.z());

            max_x = math.max(max_x, vertex.x());
            max_y = math.max(max_y, vertex.y());
            max_z = math.max(max_z, vertex.z());
        }
        return init_min_max(Vec3.init(min_x, min_y, min_z),
                            Vec3.init(max_x, max_y, max_z));
    }

    /// Combine two AABB boxes
    pub fn init_aabb(box1: AABB, box2: AABB) AABB {
        return AABB.init_min_max(minimum_vec(box1.min, box2.min),
                                    maximum_vec(box1.max, box2.max));
    }

    // Volume of AABB
    pub fn volume(box: AABB) BaseFloat {
        const diff = box.min.minus(box.max);
        return math.fabs(diff.x()) * math.fabs(diff.y()) * math.fabs(diff.z());
    }

    /// Check if ray hits the AABB
    pub fn hit_aabb(box: AABB, ray: Ray, t_min: BaseFloat, t_max: BaseFloat) bool {
        // x
        var t0 = math.min((box.min.x() - ray.origin.x()) / ray.direction.x(),
                            (box.max.x() - ray.origin.x()) / ray.direction.x());
        var t1 = math.max((box.min.x() - ray.origin.x()) / ray.direction.x(),
                            (box.max.x() - ray.origin.x()) / ray.direction.x());
        var tmin = math.max(t0, t_min);
        var tmax = math.min(t1, t_max);
        if (tmax <= tmin) {
            return false;
        }

        // y
        t0 = math.min((box.min.y() - ray.origin.y()) / ray.direction.y(),
                        (box.max.y() - ray.origin.y()) / ray.direction.y());
        t1 = math.max((box.min.y() - ray.origin.y()) / ray.direction.y(),
                        (box.max.y() - ray.origin.y()) / ray.direction.y());
        tmin = math.max(t0, t_min);
        tmax = math.min(t1, t_max);
        if (tmax <= tmin) {
            return false;
        }

        // z
        t0 = math.min((box.min.z() - ray.origin.z()) / ray.direction.z(),
                        (box.max.z() - ray.origin.z()) / ray.direction.z());
        t1 = math.max((box.min.z() - ray.origin.z()) / ray.direction.z(),
                        (box.max.z() - ray.origin.z()) / ray.direction.z());
        tmin = math.max(t0, t_min);
        tmax = math.min(t1, t_max);
        if (tmax <= tmin) {
            return false;
        }
        return true;
    }
};

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "AABB.init_min_max()" {
    const vec1 = Vec3.init(-1., 2., 3.);
    const vec2 = Vec3.init(4., -3., 7.);
    const box1 = AABB.init_min_max(vec1, vec2);
    const box2 = AABB.init_min_max(vec2, vec1);
    expectEqual(box1, box2);
    expectEqual(@as(BaseFloat, -1.), box1.min.x());
    expectEqual(@as(BaseFloat, -3.), box1.min.y());
    expectEqual(@as(BaseFloat, 3.), box1.min.z());
    expectEqual(@as(BaseFloat, 4.), box1.max.x());
    expectEqual(@as(BaseFloat, 2.), box1.max.y());
    expectEqual(@as(BaseFloat, 7.), box1.max.z());
}

test "AABB.init_aabb()" {
    const vec11 = Vec3.init(-1., 2., 3.);
    const vec12 = Vec3.init(4., -3., 7.);
    const box1 = AABB.init_min_max(vec11, vec12);
    const vec21 = Vec3.init(7., 1., 11.);
    const vec22 = Vec3.init(0., -3., -2.);
    const box2 = AABB.init_min_max(vec21, vec22);

    const box12 = AABB.init_aabb(box1, box2);
    const box21 = AABB.init_aabb(box2, box1);

    expectEqual(box12, box21);
    expectEqual(@as(BaseFloat, -1.), box12.min.x());
    expectEqual(@as(BaseFloat, -3.), box12.min.y());
    expectEqual(@as(BaseFloat, -2.), box12.min.z());
    expectEqual(@as(BaseFloat, 7.), box12.max.x());
    expectEqual(@as(BaseFloat, 2.), box12.max.y());
    expectEqual(@as(BaseFloat, 11.), box12.max.z());
}

test "AABB.init_vertexes()" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();

    try list.append(Vec3.init(-2., 0., 9.));
    try list.append(Vec3.init(1., 7., 2.));
    const box1 = AABB.init_vertexes(list);
    expectEqual(@as(BaseFloat, -2.), box1.min.x());
    expectEqual(@as(BaseFloat, 0.), box1.min.y());
    expectEqual(@as(BaseFloat, 2.), box1.min.z());
    expectEqual(@as(BaseFloat, 1.), box1.max.x());
    expectEqual(@as(BaseFloat, 7.), box1.max.y());
    expectEqual(@as(BaseFloat, 9.), box1.max.z());

    try list.append(Vec3.init(3., 0., -2.));
    try list.append(Vec3.init(-1., 2., 2.));
    try list.append(Vec3.init(9., -1., 7.));
    const box2 = AABB.init_vertexes(list);
    expectEqual(@as(BaseFloat, -2.), box2.min.x());
    expectEqual(@as(BaseFloat, -1.), box2.min.y());
    expectEqual(@as(BaseFloat, -2.), box2.min.z());
    expectEqual(@as(BaseFloat, 9.), box2.max.x());
    expectEqual(@as(BaseFloat, 7.), box2.max.y());
    expectEqual(@as(BaseFloat, 9.), box2.max.z());
}

test "AABB.volume()" {
    const box = AABB.init_min_max(Vec3.init(0.0,0.0,3.0), Vec3.init(-3.5, 2.0, 4.0));
    expectEqual(@as(BaseFloat, 7.0), box.volume());
}

test "AABB.hit() ray doesn't hit" {
    const box = AABB.init_min_max(Vec3.init(-1.0, -1.0, -1.0), Vec3.init(1.0, 1.0, 1.0));
    const ray = Ray.init(Vec3.init(-10, 0.0, 0.0), Vec3.init(-1.0, 0.0, 0.0));
    expectEqual(false, box.hit_aabb(ray, 0.0, 100000.0));
}

test "AABB.hit() ray hits" {
    const box = AABB.init_min_max(Vec3.init(-1.0, -1.0, -1.0), Vec3.init(1.0, 1.0, 1.0));
    const ray = Ray.init(Vec3.init(-10, 0.0, 0.0), Vec3.init(1.0, 0.0, 0.0));
    expectEqual(true, box.hit_aabb(ray, 0.0, 100000.0));
}
