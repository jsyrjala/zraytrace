const std = @import("std");
const Allocator = std.mem.Allocator;

//! Top level doc comment
const c_time = @cImport({
    @cInclude("time.h");
});

const math = @cImport({
    @cInclude("math.h");
});

extern fn rand() c_int;

extern fn srand(c_uint) void;

extern fn time(?*c_time.time_t) c_time.time_t;

// no c_float, these are ieee floats
extern fn sqrtf(f32) f32;

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{.x = x, .y = y, .z = z};
    }

    pub inline fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.x;
    }

    pub inline fn cross(u:Vec3, v:Vec3) Vec3 {
        return Vec3.init(u.y * v.z - u.z * v.y,
                         u.z * v.x - u.x * v.z,
                         u.x * v.y - u.y * v.x);
    }

    pub inline fn length_square(self: Vec3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub inline fn length(self: Vec3) f32 {
        return sqrtf(self.length_square());
    }

    pub inline fn unit_vector(self: Vec3) Vec3 {
        // TODO divide by zero
        const len = self.length();
        return Vec3.init(self.x / len, self.y / len, self.z / len);
    }

    pub inline fn negate(self: Vec3) Vec3 {
        // uses stack
        return Vec3.init(-self.x, -self.y, -self.z);
    }

    pub inline fn plus(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x + other.x, self.y + other.y, self.z + other.z);
    }

    pub inline fn minus(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x - other.x, self.y - other.y, self.z - other.z);
    }

    pub inline fn plus_scalar(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self.x + scalar, self.y + scalar, self.z + scalar);
    }

    pub inline fn minus_scalar(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self.x - scalar, self.y - scalar, self.z - scalar);
    }

    pub inline fn scale(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self.x * scalar, self.y * scalar, self.z * scalar);
    }

    pub inline fn multiply(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self.x * scalar, self.y * scalar, self.z * scalar);
    }

    pub inline fn divide(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self.x / scalar, self.y / scalar, self.z / scalar);
    }

    /// Reflection of a ray from fully reflecting surface
    pub inline fn reflect(v:Vec3, normal:Vec3) Vec3 {
        return v.minus(normal.scale(2 * v.dot(normal)));
        // return Vec3.minus(v, Vec3.scale(normal, 2 * Vec3.dot(v, normal)));
    }

    pub inline fn copy(allocator: *Allocator, v:Vec3) !*Vec3 {
        const new_vec3 = try allocator.create(Vec3);
        new_vec3.x = v.x;
        new_vec3.y = v.y;
        new_vec3.z = v.z;
        return new_vec3;
    }
};

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

    const t = time(null);
    const vec1 = Vec3.init(1,2,3);
    const vec2 = Vec3.init(1,0,0);
    const ray1 = Ray.init(vec1, vec2);
    srand(@intCast(c_uint, t));
    std.debug.warn("Random {}.\n", .{rand()});
    std.debug.warn("Vector {}.\n", .{vec1});
    std.debug.warn("Vector dot {}.\n", .{vec1.dot(vec1)});
    std.debug.warn("Vector length {}.\n", .{vec1.length()});
    std.debug.warn("Vector copy {}.\n", .{Vec3.copy(allocator, vec1.plus_scalar(42.0))});
}
