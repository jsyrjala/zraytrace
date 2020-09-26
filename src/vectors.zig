const std = @import("std");
const mem = std.mem;
const time = std.time;
const math = std.math;
const Random = std.rand.Random;
const ArrayList = std.ArrayList;

const Allocator = mem.Allocator;

const Vec3Float = f32;

pub const Vec3 = struct {
    _x: Vec3Float,
    _y: Vec3Float,
    _z: Vec3Float,

    pub inline fn x(v: Vec3) f32 {
        return v._x;
    }

    pub inline fn y(v: Vec3) f32 {
        return v._y;
    }

    pub inline fn z(v: Vec3) f32 {
        return v._z;
    }

    pub fn init(_x: f32, _y: f32, _z: f32) Vec3 {
        return Vec3{._x = _x, ._y = _y, ._z = _z};
    }

    pub inline fn dot(self: Vec3, other: Vec3) f32 {
        return self._x * other._x + self._y * other._y + self._z * other._x;
    }

    pub inline fn cross(u:Vec3, v:Vec3) Vec3 {
        return Vec3.init(u._y * v._z - u._z * v._y,
                         u._z * v._x - u._x * v._z,
                         u._x * v._y - u._y * v._x);
    }

    pub inline fn length_squared(self: Vec3) f32 {
        return self._x * self._x + self._y * self._y + self._z * self._z;
    }

    pub inline fn length(self: Vec3) f32 {
        return math.sqrt(self.length_squared());
    }

    pub inline fn unit_vector(self: Vec3) Vec3 {
        // TODO divide by zero
        const len = self.length();
        return Vec3.init(self._x / len, self._y / len, self._z / len);
    }

    pub inline fn negate(self: Vec3) Vec3 {
        // uses stack
        return Vec3.init(-self._x, -self._y, -self._z);
    }

    pub inline fn plus(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self._x + other._x, self._y + other._y, self._z + other._z);
    }

    pub inline fn minus(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self._x - other._x, self._y - other._y, self._z - other._z);
    }

    pub inline fn plusScalar(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self._x + scalar, self._y + scalar, self._z + scalar);
    }

    pub inline fn minusScalar(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self._x - scalar, self._y - scalar, self._z - scalar);
    }

    pub inline fn scale(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self._x * scalar, self._y * scalar, self._z * scalar);
    }

    pub inline fn multiply(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self._x * scalar, self._y * scalar, self._z * scalar);
    }

    // Divide vector by scalar
    pub inline fn divide(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self._x / scalar, self._y / scalar, self._z / scalar);
    }

    /// Reflection of a ray from fully reflecting surface
    pub inline fn reflect(v:Vec3, normal:Vec3) Vec3 {
        return v.minus(normal.scale(2 * v.dot(normal)));
    }

    /// Copy allocate storage and copy vector.
    pub inline fn copy(allocator: *Allocator, v:Vec3) !*Vec3 {
        const new_vec3 = try allocator.create(Vec3);
        new_vew.* = v;
        return new_vec3;
    }

    /// Returns a center point for vectors
    pub fn center(vectors: ArrayList(Vec3)) Vec3 {
        const len_scale = 1.0 / @intToFloat(f32, vectors.items.len);
        var x_sum: f32 = 0.0;
        var y_sum: f32 = 0.0;
        var z_sum: f32 = 0.0;
        for (vectors.items) |*vector, i| {
            x_sum += vector._x * len_scale;
            y_sum += vector._y * len_scale;
            z_sum += vector._z * len_scale;
        }
        return Vec3.init(x_sum, y_sum, z_sum);
    }

    /// Generate random vector where each
    /// coordinate is between min and max.
    pub inline fn random_vector(random: *Random, min: f32, max: f32) Vec3 {
        var r = DefaultPrng.init(0).random;
        const x_val = random.float(f32) * 2.0 - 1.0;
        const y_val = random.float(f32) * 2.0 - 1.0;
        const z_val = random.float(f32) * 2.0 - 1.0;
        return Vec3.init(x_val, y_val, z_val);
    }

    /// Generate random vector that is inside a unit sphere.
    /// Length is <= 1.0.
    pub inline fn random_vector_in_unit_sphere(random: *Random) Vec3 {
        while (true) {
            const p = Vec3.random_vector(random, -1.0, 1.0);
            if (Vec3.length_squared(p) > 1.0) {
                continue;
            }
            return p;
        }
        return unreachable;
    }

    // Returns random unit vector
    pub inline fn random_unit_vector(random: *Random) Vec3 {
        while (true) {
            const p = random_vector_in_unit_sphere(random);
            const unit_p = Vec3.unit_vector(p);
            if (math.isNan(unit_p._x)) {
                // zero length vector is skipped
                continue;
            }
            return unit_p;
        }
    }
};

///// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const DefaultPrng = std.rand.DefaultPrng;

test "Vec3.dot" {
    const vec_0 = Vec3.init(0.0, 0.0, 0.0);
    const vec_unit_x = Vec3.init(1.0, 0.0, 0.0);
    const vec_unit_y = Vec3.init(0.0, 1.0, 0.0);
    expectEqual(@as(f32, 0.0), vec_0.dot(vec_unit_x));
    expectEqual(@as(f32, 0.0), vec_unit_x.dot(vec_unit_y));
    expectEqual(@as(f32, 1.0), vec_unit_x.dot(vec_unit_x));
}

test "Vec3.unit_vector() with zero length vector" {
    const vec_0 = Vec3.init(0.0, 0.0, 0.0);
    const zero_unit = vec_0.unit_vector();
    expect(math.isNan(zero_unit.x()));
    expect(math.isNan(zero_unit.y()));
    expect(math.isNan(zero_unit.z()));
}

test "Vec3.unit_vector() with non-zero length vector" {
    const vec_1 = Vec3.init(1.0, 0.0, 0.0);
    const vec_2 = Vec3.init(3.0, -4.0, 0.0);
    expectEqual(vec_1, vec_1.unit_vector());
    expectEqual(Vec3.init(0.6, -0.8, 0.0), vec_2.unit_vector());
}


test "Vec3.center with zero vectors" {
    const allocator = std.heap.page_allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();

    const center_vector = Vec3.center(list);
    expectEqual(@as(f32, 0.0), center_vector.x());
    expectEqual(@as(f32, 0.0), center_vector.y());
    expectEqual(@as(f32, 0.0), center_vector.z());
}

test "Vec3.center() with one vectors" {
    const allocator = std.heap.page_allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();

    const vec1 = Vec3.init(1.0, 2.0, 4.0);
    try list.append(vec1);
    const center_vector = Vec3.center(list);
    expectEqual(@as(f32, 1.0), center_vector.x());
    expectEqual(@as(f32, 2.0), center_vector.y());
    expectEqual(@as(f32, 4.0), center_vector.z());
}

test "Vec3.center() with three vectors" {
    const allocator = std.heap.page_allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();

    const vec1 = Vec3.init(1.0, 2.0, 4.0);
    const vec2 = Vec3.init(-1.0, -2.0, -4.0);
    const vec3 = Vec3.init(-3.0, 6.0, -12.0);
    try list.append(vec1);
    try list.append(vec2);
    try list.append(vec3);
    const center_vector = Vec3.center(list);
    expectEqual(@as(f32, -1.0), center_vector.x());
    expectEqual(@as(f32, 2.0), center_vector.y());
    expectEqual(@as(f32, -4.0), center_vector.z());
}

test "random_vector()" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const vector = Vec3.random_vector(random, -1.0, 1.0);

    const expected = Vec3.init(-0.7746, 0.3873, -0.7065);
    expect(math.absFloat(expected.x() - vector.x()) < 0.01);
    expect(math.absFloat(expected.y() - vector.y()) < 0.01);
    expect(math.absFloat(expected.z() - vector.z()) < 0.01);
    // length may or may not be larger than 1, now
    // it happens to be
    expect(Vec3.length(vector) > 1.0);
}

test "random_in_unit_sphere" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const vector = Vec3.random_vector_in_unit_sphere(random);

    const expected = Vec3.init(0.1846, 0.8305, -0.0479);
    expect(math.absFloat(expected.x() - vector.x()) < 0.01);
    expect(math.absFloat(expected.y() - vector.y()) < 0.01);
    expect(math.absFloat(expected.z() - vector.z()) < 0.01);
    expect(Vec3.length(vector) < 1.0);
}

test "random_unit_vector" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const vector = Vec3.random_unit_vector(random);
    const expected = Vec3.init(0.2167, 0.9746, -0.0562);
    expect(math.absFloat(expected.x() - vector.x()) < 0.01);
    expect(math.absFloat(expected.y() - vector.y()) < 0.01);
    expect(math.absFloat(expected.z() - vector.z()) < 0.01);
    expect(Vec3.length(vector) < 1.01);
    expect(Vec3.length(vector) > 0.99);
}
