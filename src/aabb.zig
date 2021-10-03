//! Axis Aligned Bounding Box
const std = @import("std");
const Allocator = std.mem.Allocator;
const BaseFloat = @import("base.zig").BaseFloat;
const Vec3 = @import("vector.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const ArrayList = std.ArrayList;
const math = std.math;

pub const AABB = struct {
    min: Vec3,
    max: Vec3,
    midpoint: Vec3,

    /// Return a vector that contains minimum coordinates
    fn minimumVec(vec1: Vec3, vec2: Vec3) Vec3 {
        return Vec3.init(math.min(vec1.x(), vec2.x()),
                         math.min(vec1.y(), vec2.y()),
                         math.min(vec1.z(), vec2.z()));
    }

    /// Return a vector that contains maximum coordinates
    fn maximumVec(vec1: Vec3, vec2: Vec3) Vec3 {
        return Vec3.init(math.max(vec1.x(), vec2.x()),
                         math.max(vec1.y(), vec2.y()),
                         math.max(vec1.z(), vec2.z()));
    }

    /// Return a vector that contains midpoint coordinates
    fn midpointVec(vec1: Vec3, vec2: Vec3) Vec3 {
        return Vec3.init((vec1.x() + vec2.x()) / 2.0,
                         (vec1.y() + vec2.y()) / 2.0,
                         (vec1.z() + vec2.z()) / 2.0);
    }

    /// Create AABB from two vertices
    pub fn initMinMax(corner1: Vec3, corner2: Vec3) AABB {
        return AABB{.min = minimumVec(corner1, corner2),
                    .max = maximumVec(corner1, corner2),
                    .midpoint = midpointVec(corner1, corner2)};
    }

    /// Create AABB from list of vertices
    pub fn initVertexes(vertexes: []Vec3) AABB {
        std.debug.assert(vertexes.len > 1);
        var min_x = math.inf(BaseFloat);
        var min_y = math.inf(BaseFloat);
        var min_z = math.inf(BaseFloat);

        var max_x = -math.inf(BaseFloat);
        var max_y = -math.inf(BaseFloat);
        var max_z = -math.inf(BaseFloat);

        for (vertexes) |*vertex| {
            min_x = math.min(min_x, vertex.x());
            min_y = math.min(min_y, vertex.y());
            min_z = math.min(min_z, vertex.z());

            max_x = math.max(max_x, vertex.x());
            max_y = math.max(max_y, vertex.y());
            max_z = math.max(max_z, vertex.z());
        }
        return initMinMax(Vec3.init(min_x, min_y, min_z),
                            Vec3.init(max_x, max_y, max_z));
    }

    /// Combine two AABB boxes
    pub fn initAabb(box1: AABB, box2: AABB) AABB {
        return AABB.initMinMax(minimumVec(box1.min, box2.min),
                               maximumVec(box1.max, box2.max));
    }

    pub fn initAabbList(allocator: *Allocator, aabb_list: []AABB) anyerror! AABB {
        var vec_list = ArrayList(Vec3).init(allocator);
        defer vec_list.deinit();
        for (aabb_list) |aabb| {
            try vec_list.append(aabb.min);
            try vec_list.append(aabb.max);
        }
        return initVertexes(vec_list.items);
    }

    /// Volume of AABB
    pub fn volume(box: AABB) BaseFloat {
        const diff = box.min.minus(box.max);
        return math.fabs(diff.x()) * math.fabs(diff.y()) * math.fabs(diff.z());
    }

    /// Used when printing struct
    pub fn format(self: AABB, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        return std.fmt.format(writer, "AABB(Min({d:0.3},{d:0.3},{d:0.3}),Max({d:0.3},{d:0.3},{d:0.3}))",
                            .{self.min.x(), self.min.y(), self.min.z(),
                              self.max.x(), self.max.y(), self.max.z(),});
    }

    /// Surface area oof AABB
    pub fn surfaceArea(box: AABB) BaseFloat {
        const diff = box.min.minus(box.max);
        const d_x = math.fabs(diff.x());
        const d_y = math.fabs(diff.y());
        const d_z = math.fabs(diff.z());
        return 2 * (d_x * d_x + d_y * d_y + d_z * d_z);
    }

    /// Check if ray hits the AABB
    /// Optimized method https://raytracing.github.io/books/RayTracingTheNextWeek.html#boundingvolumehierarchies/anoptimizedaabbhitmethod
    pub inline fn hitAabb(box: AABB, ray: *const Ray, t_min: BaseFloat, t_max: BaseFloat) bool {
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            const inv_d: BaseFloat = 1.0 / ray.direction.elem(i);
            var t0: BaseFloat = (box.min.elem(i) - ray.origin.elem(i)) * inv_d;
            var t1: BaseFloat = (box.max.elem(i) - ray.origin.elem(i)) * inv_d;
            if (inv_d < 0.0) {
                var tmp = t0;
                t0 = t1;
                t1 = tmp;
            }
            const tmin = math.max(t0, t_min);
            const tmax = math.min(t1, t_max);
            if (tmax <= tmin) {
                return false;
            }
        }
        return true;
    }

    /// Check if ray hits the AABB
    pub inline fn hitAabb_2(box: AABB, ray: Ray, t_min: BaseFloat, t_max: BaseFloat) bool {
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            var t0 = math.min((box.min.elem(i) - ray.origin.elem(i)) / ray.direction.elem(i),
                                (box.max.elem(i) - ray.origin.elem(i)) / ray.direction.elem(i));
            var t1 = math.max((box.min.elem(i) - ray.origin.elem(i)) / ray.direction.elem(i),
                                (box.max.elem(i) - ray.origin.elem(i)) / ray.direction.elem(i));
            const tmin = math.max(t0, t_min);
            const tmax = math.min(t1, t_max);
            if (tmax <= tmin) {
                return false;
            }
        }
        return true;
    }
};

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "AABB.initMinMax()" {
    const vec1 = Vec3.init(-1.0, 2.0, 3.0);
    const vec2 = Vec3.init(4.0, -3.0, 7.0);
    const box1 = AABB.initMinMax(vec1, vec2);
    const box2 = AABB.initMinMax(vec2, vec1);
    expectEqual(box1, box2);
    expectEqual(@as(BaseFloat, -1.0), box1.min.x());
    expectEqual(@as(BaseFloat, -3.0), box1.min.y());
    expectEqual(@as(BaseFloat, 3.0), box1.min.z());
    expectEqual(@as(BaseFloat, 4.0), box1.max.x());
    expectEqual(@as(BaseFloat, 2.0), box1.max.y());
    expectEqual(@as(BaseFloat, 7.0), box1.max.z());
}

test "AABB.initAabb()" {
    const vec11 = Vec3.init(-1.0, 2.0, 3.0);
    const vec12 = Vec3.init(4.0, -3.0, 7.0);
    const box1 = AABB.initMinMax(vec11, vec12);
    const vec21 = Vec3.init(7.0, 1.0, 11.0);
    const vec22 = Vec3.init(0.0, -3.0, -2.0);
    const box2 = AABB.initMinMax(vec21, vec22);

    const box12 = AABB.initAabb(box1, box2);
    const box21 = AABB.initAabb(box2, box1);

    expectEqual(box12, box21);
    expectEqual(@as(BaseFloat, -1.0), box12.min.x());
    expectEqual(@as(BaseFloat, -3.0), box12.min.y());
    expectEqual(@as(BaseFloat, -2.0), box12.min.z());
    expectEqual(@as(BaseFloat, 7.0), box12.max.x());
    expectEqual(@as(BaseFloat, 2.0), box12.max.y());
    expectEqual(@as(BaseFloat, 11.0), box12.max.z());
}

test "AABB.initVertexes()" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();

    try list.append(Vec3.init(-2.0, 0.0, 9.0));
    try list.append(Vec3.init(1.0, 7.0, 2.0));
    const box1 = AABB.initVertexes(list.items);
    expectEqual(@as(BaseFloat, -2.0), box1.min.x());
    expectEqual(@as(BaseFloat, 0.0), box1.min.y());
    expectEqual(@as(BaseFloat, 2.0), box1.min.z());
    expectEqual(@as(BaseFloat, 1.0), box1.max.x());
    expectEqual(@as(BaseFloat, 7.0), box1.max.y());
    expectEqual(@as(BaseFloat, 9.0), box1.max.z());

    try list.append(Vec3.init(3.0, 0.0, -2.0));
    try list.append(Vec3.init(-1.0, 2.0, 2.0));
    try list.append(Vec3.init(9.0, -1.0, 7.0));
    const box2 = AABB.initVertexes(list.items);
    expectEqual(@as(BaseFloat, -2.0), box2.min.x());
    expectEqual(@as(BaseFloat, -1.0), box2.min.y());
    expectEqual(@as(BaseFloat, -2.0), box2.min.z());
    expectEqual(@as(BaseFloat, 9.0), box2.max.x());
    expectEqual(@as(BaseFloat, 7.0), box2.max.y());
    expectEqual(@as(BaseFloat, 9.0), box2.max.z());
}

test "AABB.initAabbList()" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    var list = ArrayList(AABB).init(allocator);
    defer list.deinit();

    try list.append(AABB.initMinMax(Vec3.init(-10.0,0.0,-3.0), Vec3.init(-3.5, 12.5, -4.0)));
    try list.append(AABB.initMinMax(Vec3.init(0.0,-7.0,-3.0), Vec3.init(10.5, 2.0, -4.0)));
    try list.append(AABB.initMinMax(Vec3.init(0.0,0.0,-11.0), Vec3.init(-3.5, 12.0, -1.0)));
    
    const box = try AABB.initAabbList(allocator, list.items);
    expectEqual(@as(BaseFloat, -10.0), box.min.x());
    expectEqual(@as(BaseFloat, -7.0), box.min.y());
    expectEqual(@as(BaseFloat, -11.0), box.min.z());
    expectEqual(@as(BaseFloat, 10.5), box.max.x());
    expectEqual(@as(BaseFloat, 12.5), box.max.y());
    expectEqual(@as(BaseFloat, -1.0), box.max.z());
}

test "AABB.volume()" {
    const box = AABB.initMinMax(Vec3.init(0.0,0.0,3.0), Vec3.init(-3.5, 2.0, 4.0));
    expectEqual(@as(BaseFloat, 7.0), box.volume());
}

test "AABB.surfaceArea()" {
    const box = AABB.initMinMax(Vec3.origin, Vec3.init(1, -2.0, 3.0));
    expectEqual(@as(BaseFloat, 2.0 + 8.0 + 18.0), box.surfaceArea());
}

test "AABB.hit() ray doesn't hit" {
    const box = AABB.initMinMax(Vec3.init(-1.0, -1.0, -1.0), Vec3.init(1.0, 1.0, 1.0));
    const ray = Ray.init(Vec3.init(-10, 0.0, 0.0), Vec3.init(-1.0, 0.0, 0.0));
    expectEqual(false, box.hitAabb(&ray, 0.0, 100000.0));
}

test "AABB.hit() ray hits" {
    const box = AABB.initMinMax(Vec3.init(-1.0, -1.0, -1.0), Vec3.init(1.0, 1.0, 1.0));
    const ray = Ray.init(Vec3.init(-10, 0.0, 0.0), Vec3.init(1.0, 0.0, 0.0));
    expectEqual(true, box.hitAabb(&ray, 0.0, 100000.0));
}
