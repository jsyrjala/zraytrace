//! Bounded Volume Hierarchy
//! A tree of AABB that contain other AABBs or Surfaces
//! The idea is to divide space to hierarchy of AABBs, to quicly
//! remove areas which can't have intersections with the ray
//! https://raytracing.github.io/books/RayTracingTheNextWeek.html#boundingvolumehierarchies
//! http://www.pbr-book.org/3ed-2018/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies.html
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.rand.Random;
const Sample = @import("sample.zig").Sample;
const BaseFloat = @import("base.zig").BaseFloat;
const AABB = @import("aabb.zig").AABB;
const Vec3 = @import("vector.zig").Vec3;
const Surface = @import("surface.zig").Surface;
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("hit_record.zig").HitRecord;

// TODO compact array based layout
// http://www.pbr-book.org/3ed-2018/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies.html#CompactBVHForTraversal

/// Tracking for maximum reached depth
const Tracking = struct {
    max_depth: u64,
    fn update(tracking: *Tracking, depth: u64) void {
        if (tracking.max_depth < depth) {
            tracking.max_depth = depth;
        }
    }
};

pub const BVHNode = struct {
    aabb: AABB,
    left_child: *Surface,
    right_child: *Surface,

    // Comparator functions sort by minimum AABB coordinates
    fn compareX(a: *Surface, b: *Surface) bool {
        return a.aabb().midpoint.x() < b.aabb().midpoint.x();
    }

    fn compareY(a: *Surface, b: *Surface) bool {
        return a.aabb().midpoint.y() < b.aabb().midpoint.y();
    }

    fn compareZ(a: *Surface, b: *Surface) bool {
        return a.aabb().midpoint.z() < b.aabb().midpoint.z();
    }

    const axis_comparators = [_]* const fn (a: *Surface, b: *Surface) bool{&compareX, &compareY, &compareZ};

    fn lessThanAxis(axis_index: u8, a: *Surface, b: *Surface) bool {
        const comparator = axis_comparators[axis_index];
        return comparator.*(a, b);
    }

    const SurfaceDivide = struct {
        left_surfaces: []*Surface,
        right_surfaces: []*Surface,
    };

    fn surfaces_to_aabb(allocator: *Allocator, surfaces: []*Surface) !AABB {
        var aabbs = ArrayList(AABB).init(allocator);
        defer aabbs.deinit();
        for (surfaces) |surface| {
            try aabbs.append(surface.aabb());
        }
        return AABB.initAabbList(allocator, aabbs.items);
    }

    fn make_axis_divide(axis_index: u8, surfaces: []*Surface, split: usize) SurfaceDivide {
        std.sort.sort(*Surface, surfaces, axis_index, lessThanAxis);
        const left_surfaces = surfaces[0..split];
        const right_surfaces = surfaces[split..];
        return SurfaceDivide{
            .left_surfaces = left_surfaces,
            .right_surfaces = right_surfaces
        };
    }

    /// Split surfaces evenly on the axis that gives the smallest surface area for the AABBs
    /// http://www.pbr-book.org/3ed-2018/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies.html#TheSurfaceAreaHeuristic
    /// TODO this splits by items, densely populated areas get more splits, would be better to split by dividing space
    ///       to buckets
    fn optimal_axis_divide(allocator: *Allocator, surfaces: []*Surface) !SurfaceDivide {
        // Try splitting with every axis, and use the best one
        var best_axis_index: u8 = 0;
        var best_area: f32 = std.math.inf(f32);
        var best_ratio: f32 = std.math.inf(f32);
        var best_split = surfaces.len / 2;

        const total_aabb = try surfaces_to_aabb(allocator, surfaces);
        const total_area = total_aabb.surfaceArea();

        var splits: []usize = &[_]usize{surfaces.len / 2};
        if (surfaces.len >= 4) {
            splits = &[_]usize{surfaces.len / 4, surfaces.len / 2, surfaces.len / 4 + surfaces.len / 2};
        }

        var axis_index: u8 = 0;
        while (axis_index < 3) : (axis_index += 1) {
            for (splits) |split| {
                const axis_divide = make_axis_divide(axis_index, surfaces, split);
                const right_aabb = try surfaces_to_aabb(allocator, axis_divide.right_surfaces);
                const left_aabb = try surfaces_to_aabb(allocator, axis_divide.left_surfaces);
                const area = right_aabb.surfaceArea() + left_aabb.surfaceArea();
                const ratio = area / total_area;
                if (ratio < best_ratio) {
                    best_area = area;
                    best_ratio = ratio;
                    best_axis_index = axis_index;
                    best_split = split;
                }
            }
        }
        // redo the best split
        // TODO this might make a different split if the sort is not stable
        // TODO better would be store sorts to different buffers, and not touch the originals
        return make_axis_divide(best_axis_index, surfaces, best_split);
    }

    /// Split surfaces evenly on randomly selected axis
    fn random_axis_divide(random: *Random, surfaces: []*Surface) anyerror ! SurfaceDivide {
        const axis_index = random.intRangeAtMost(u8, 0, 2);
        var split = surfaces.len / 2;
        return make_axis_divide(axis_index, surfaces, split);
    }

    fn divide(allocator: *Allocator, random: *Random, surfaces: []*Surface, depth: u32, tracking: *Tracking) anyerror ! *Surface {
        std.debug.assert(surfaces.len > 0);
        tracking.update(depth);
        if (surfaces.len == 1) {
            // same node is added to both sides to simplify code
            const surface = surfaces[0];
            return BVHNode.create(allocator, random, surface, surface);
        }

        if (surfaces.len == 2) {
            const surface0 = surfaces[0];
            const surface1 = surfaces[1];
            // Does not matter which is left and which is right
            return BVHNode.create(allocator, random, surface1, surface0);
        }

        // Total runtime:         40.56 seconds
        //   Prepare runtime:     1.12 seconds
        //   Render runtime:      39.44 seconds
        const axis_divide = try optimal_axis_divide(allocator, surfaces);

        // Total runtime:         42.89 seconds
        //   Prepare runtime:     0.23 seconds
        //   Render runtime:      42.65 seconds
        // const axis_divide = try random_axis_divide(random, surfaces);

        std.debug.assert(surfaces.len == axis_divide.left_surfaces.len + axis_divide.right_surfaces.len);

        const left = try divide(allocator, random, axis_divide.left_surfaces, depth + 1, tracking);
        const right = try divide(allocator, random, axis_divide.right_surfaces, depth + 1, tracking);
        return BVHNode.create(allocator, random, left, right);
    }

    fn create(allocator: *Allocator, random: *Random, left: *Surface, right: *Surface) ! *Surface {
        _ = random;
        const aabb = AABB.initAabb(left.aabb(), right.aabb());
        const bvh_node = BVHNode{.left_child = left, .right_child = right, .aabb = aabb};
        const surface = try allocator.create(Surface);
        surface.* = Surface.initBVHNode(bvh_node);
        return surface;
    }

    pub fn init(allocator: *Allocator, random: *Random, surfaces: *ArrayList(*Surface)) ! BVHNode {
        // TODO create own Arena allocator here?
        var tracking = try allocator.create(Tracking);
        defer allocator.destroy(tracking);
        tracking.* = Tracking{.max_depth = 0};

        std.debug.warn("Computing Bounded Volume Hierarchy for {} surfaces\n", .{surfaces.items.len});
        var root_node = try divide(allocator, random, surfaces.items, 1, tracking);
        std.debug.warn("Max depth in BVH is {}\n", .{tracking.max_depth});

        // here root bhv_node is wrapped in a Surface, releasing it now
        const root_bvh_node = root_node.bvh_node;
        allocator.destroy(root_node);
        return root_bvh_node;
    }

    pub fn hit(node: *const BVHNode, surface: *const Surface, ray: *const Ray, t_min: f32, t_max: f32) ?HitRecord {
        _ = surface;
        if (!node.aabb.hitAabb(ray, t_min, t_max)) {
            // no hit on bounding box, can't hit anything inside the bounding box
            return null;
        }
        const hit_left: ?HitRecord = node.left_child.hit(ray, t_min, t_max);
        if (hit_left == null) {
            // no hits on left, return whatever hits on right
            return node.right_child.hit(ray, t_min, t_max);
        }
        const hit_right = node.right_child.hit(ray, t_min, hit_left.?.t);
        if (hit_right != null) {
            // hit on right that is closer than hit_left
            return hit_right;
        }
        // no hit on right, or it is farther than hit_left
        return hit_left;
    }
};

//// Testing
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;
const Sphere = @import("sphere.zig").Sphere;
const Triangle = @import("triangle.zig").Triangle;
const Material = @import("material.zig").Material;

fn createAabb() AABB {
    const u = Vec3.init(7.0, 2, -4.0);
    const v = Vec3.init(-1.0, 0, 1.0);
    const aabb = AABB.initMinMax(u, v);
    return aabb;
}

fn createSphere(allocator: *Allocator, sphere: Sphere) !*Surface {
    const surface = try allocator.create(Surface);
    surface.* = Surface.initSphere(sphere);
    return surface;
}

fn createTriangle(allocator: *Allocator, triangle: Triangle) !*Surface {
    const surface = try allocator.create(Surface);
    surface.* = Surface.initTriangle(triangle);
    return surface;
}

fn createSurfaces(allocator: *Allocator, random: *Random, count: u16) !ArrayList(*Surface) {
    var surfaces = ArrayList(*Surface).init(allocator);

    var i: u16 = 0;
    while(i < count) : (i += 1) {
        const x: f32 = (random.float(f32) - 0.5) * 100.0;
        const y: f32 = (random.float(f32) - 0.5) * 100.0;
        const z: f32 = (random.float(f32) - 0.5) * 100.0;
        const radius: f32 = random.float(f32) * 10 + 0.01;
        const center = Vec3.init(x,y,z);
        try surfaces.append(try createSphere(allocator, Sphere.init(center, radius, &Material.black_metal)));
    }
    return surfaces;
}

test "BVHNode.init()" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    var surfaces = try createSurfaces(allocator, random, 1011);
    defer surfaces.deinit();
    _ = BVHNode.init(allocator, random, &surfaces);
}

test "BVHNode.hit()" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    var surfaces = try createSurfaces(allocator, random, 3127);
    defer surfaces.deinit();
    const bvh_node = try BVHNode.init(allocator, random, &surfaces);
    // defer bvh_node.deinit();

    const bvh_surface = Surface.initBVHNode(bvh_node);

    const ray_count = 2000;
    var i: u64 = 0;
    var hits: u64 = 0;
    while (i<ray_count) : ( i+= 1) {
        const ray = Ray.init(Sample.randomUnitVector(random).scale(100.0), Sample.randomUnitVector(random));
        const hit = bvh_surface.hit(&ray, 0.0001, std.math.inf(BaseFloat));
        if (hit != null) {
            hits += 1;
        }
    }

    std.debug.warn("Got {} hits from {} rays\n", .{hits, ray_count});
    expect(hits > 10);
    expect(hits < 1500);
}
