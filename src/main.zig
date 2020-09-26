const std = @import("std");
const mem = std.mem;
const time = std.time;
const math = std.math;
const Random = std.rand.Random;
const DefaultPrng = std.rand.DefaultPrng;

const Allocator = mem.Allocator;


pub const Ray = struct {
    origin: Vec3,
    direction: Vec3,

    pub inline fn init(origin: Vec3, direction: Vec3) Ray {
        return Ray{.origin = origin, .direction = direction};
    }
    pub inline fn ray_at(self:Ray, t:f32) Vec3 {
        return self.origin.add(self.direction.scale(t));
    }

    pub inline fn copy(allocator: *Allocator, ray:Ray) !*Ray {
        const new_ray = try allocator.create(Ray);
        new_ray.origin = try Vec3.copy(allocator, origin);
        new_ray.direction = try Vec3.copy(allocator, origin);
        return new_ray;
    }
};
/// Doc string
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const t = time.milliTimestamp();

    // why const is not allowed here? error: expected type '*std.rand.Random', found '*const std.rand.Random'
    var r= DefaultPrng.init(t);
    const vec1 = Vec3.init(1,2,3);
    const vec2 = Vec3.init(1,0,0);
    const ray1 = Ray.init(vec1, vec2);

    // srand(@intCast(c_uint, t));
    std.debug.warn("Random {}.\n", .{r.random.int(i64)});
    std.debug.warn("Vector {}.\n", .{vec1});
    std.debug.warn("Vector dot {}.\n", .{vec1.dot(vec1)});
    std.debug.warn("Vector length {}.\n", .{vec1.length()});
    std.debug.warn("Vector copy {}.\n", .{Vec3.copy(allocator, vec1.plus_scalar(42.0))});
}
