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
usingnamespace @import("base.zig");
usingnamespace @import("aabb.zig");
usingnamespace @import("vector.zig");
usingnamespace @import("surface.zig");
usingnamespace @import("ray.zig");
usingnamespace @import("hit_record.zig");

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
    fn compare_x(a: *Surface, b: *Surface) bool {
        return a.aabb().min.x() < b.aabb().min.x();
    }

    fn compare_y(a: *Surface, b: *Surface) bool {
        return a.aabb().min.y() < b.aabb().min.y();
    }

    fn compare_z(a: *Surface, b: *Surface) bool {
        return a.aabb().min.z() < b.aabb().min.z();
    }

    const axis_comparators = [_]* const fn (a: *Surface, b: *Surface) bool{&compare_x, &compare_y, &compare_z};

    fn divide(allocator: *Allocator, random: *Random, surfaces: []*Surface, depth: u32, tracking: *Tracking) anyerror ! *Surface {
        std.debug.assert(surfaces.len > 0);
        tracking.update(depth);
        if (surfaces.len == 1) {
            // same node is added to both sides to simplify code
            const surface = surfaces[0];
            return BVHNode.create(allocator, random, surface, surface);
        }

        const comparator_index = random.intRangeAtMost(u8, 0, 2);
        const comparator = axis_comparators[comparator_index].*;

        if (surfaces.len == 2) {
            const surface0 = surfaces[0];
            const surface1 = surfaces[1];
            if (comparator(surface0, surface0)) {
                return BVHNode.create(allocator, random, surface0, surface1);
            }
            return BVHNode.create(allocator, random, surface1, surface0);
        }
        std.sort.sort(*Surface, surfaces, comparator);
        const split = surfaces.len / 2;
        const left_surfaces = surfaces[0..split];
        const right_surfaces = surfaces[split..];

        std.debug.assert(surfaces.len == left_surfaces.len + right_surfaces.len);

        const left = try divide(allocator, random, surfaces[0..split], depth + 1, tracking);
        const right = try divide(allocator, random, surfaces[split..], depth + 1, tracking);
        return BVHNode.create(allocator, random, left, right);
    }

    fn create(allocator: *Allocator, random: *Random, left: *Surface, right: *Surface) ! *Surface {
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

    pub fn hit(node: BVHNode, surface: Surface, ray: Ray, t_min: f32, t_max: f32) ?HitRecord {
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
        try surfaces.append(try createSphere(allocator, Sphere.init(center, radius, Material.black_metal)));
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
    const bvh_node = BVHNode.init(allocator, random, &surfaces);
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
        const ray = Ray.init(Vec3.randomUnitVector(random).scale(100.0), Vec3.randomUnitVector(random));
        const hit = bvh_surface.hit(ray, 0.0001, std.math.inf(BaseFloat));
        if (hit != null) {
            hits += 1;
        }
    }

    std.debug.warn("Got {} hits from {} rays\n", .{hits, ray_count});
    expect(hits > 10);
    expect(hits < 1500);
}
