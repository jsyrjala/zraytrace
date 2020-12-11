const Sphere = @import("sphere.zig").Sphere;
const Triangle = @import("triangle.zig").Triangle;
const Color = @import("image.zig").Color;
const Vec3 = @import("vector.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("hit_record.zig").HitRecord;
const Material = @import("material.zig").Material;
usingnamespace @import("aabb.zig");
usingnamespace @import("bvh.zig");

/// Surface is a "supertype" for all surfaces.
pub const Surface = union (enum) {
    sphere: Sphere,
    triangle: Triangle,
    bvh_node: BVHNode,

    pub fn initSphere(sphere: Sphere) Surface {
        return Surface{.sphere = sphere};
    }
    pub fn initTriangle(triangle: Triangle) Surface {
        return Surface{.triangle = triangle};
    }
    pub fn initBVHNode(bvh_node: BVHNode) Surface {
        return Surface{.bvh_node = bvh_node};
    }

    /// Find the right surface type and call it's hit method
    pub inline fn hit(surface: *const Surface, ray: *const Ray, t_min: f32, t_max: f32) ?HitRecord {
        switch (surface.*) {
            Surface.bvh_node => |obj| return obj.hit(surface, ray, t_min, t_max),
            Surface.triangle => |obj| return obj.hit(surface, ray, t_min, t_max),
            Surface.sphere => |obj| return obj.hit(surface, ray, t_min, t_max),
        }
        std.debug.warn("Surface.hit() unreachable.", .{});
        unreachable;
    }

    // one way to do polymorphism
    pub inline fn material(surface: *const Surface) *const Material {
        switch (surface.*) {
            Surface.triangle => |obj| return obj.material,
            Surface.sphere => |obj| return obj.material,
            // no material for bvh node
            else => unreachable
        }
        std.debug.warn("Surface.material() unreachable.", .{});
        unreachable;
    }

    // other way to do polymorphism, code should be about identical in this and above
    pub inline fn aabb(surface: *const Surface) AABB {
        const enum_fields = comptime std.meta.fields(@TagType(Surface));
        inline for (std.meta.fields(Surface)) |field, i| {
            if (@enumToInt(surface.*) == enum_fields[i].value) {
                return @field(surface.*, field.name).aabb;
            }
        }
        std.debug.warn("Surface.aabb() unreachable. {}", .{surface});
        unreachable;
    }
};

//// Testing
const ArrayList = @import("std").ArrayList;
const std = @import("std");

test "Surface.hit()" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const sphere = Sphere.init(Vec3.z_unit, 0.1, &Material.black_metal);
    const s = Surface.initSphere(sphere);
    const triangle = Triangle.init(Vec3.x_unit, Vec3.z_unit, Vec3.y_unit, &Material.black_metal);
    const t = Surface.initTriangle(triangle);
    const ray = Ray.init(Vec3.origin, Vec3.x_unit);

    var surfaces = ArrayList(Surface).init(allocator);
    defer surfaces.deinit();
    try surfaces.append(Surface{.triangle = triangle});
    try surfaces.append(Surface{.sphere = sphere});
    for (surfaces.items) |*surface| {
        _ = surface.hit(&ray, 1.0, 20.0);
        _ = surface.aabb();
    }
}
