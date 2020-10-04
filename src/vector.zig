//! Basic vector maths
const std = @import("std");
const base = @import("base.zig");
const mem = std.mem;
const time = std.time;
const math = std.math;
const Random = std.rand.Random;
const ArrayList = std.ArrayList;

const Allocator = mem.Allocator;

const BaseFloat = base.BaseFloat;

pub const Vec3 = struct {
    _x: BaseFloat,
    _y: BaseFloat,
    _z: BaseFloat,

    pub const origin = Vec3.init(0., 0., 0.);
    pub const x_unit = Vec3.init(1., 0., 0.);
    pub const y_unit = Vec3.init(0., 1., 0.);
    pub const z_unit = Vec3.init(0., 0., 1.);

    pub inline fn elem(v: Vec3, index: u8) BaseFloat {
        switch (index) {
            0 => return v.x(),
            1 => return v.y(),
            2 => return v.z(),
            else => unreachable
        }
    }

    /// Used when printing struct
    pub fn format(self: Vec3, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        return std.fmt.format(writer, "Vec3({},{},{})", .{self._x, self._y, self._z,});
    }

    pub inline fn x(v: Vec3) BaseFloat {
        return v._x;
    }

    pub inline fn y(v: Vec3) BaseFloat {
        return v._y;
    }

    pub inline fn z(v: Vec3) BaseFloat {
        return v._z;
    }

    pub fn init(_x: BaseFloat, _y: BaseFloat, _z: BaseFloat) Vec3 {
        return Vec3{._x = _x, ._y = _y, ._z = _z};
    }

    /// Dot product
    pub inline fn dot(self: Vec3, other: Vec3) BaseFloat {
        return self._x * other._x + self._y * other._y + self._z * other._z;
    }

    /// Cross product
    pub inline fn cross(u:Vec3, v:Vec3) Vec3 {
        return Vec3.init(u._y * v._z - u._z * v._y,
                         u._z * v._x - u._x * v._z,
                         u._x * v._y - u._y * v._x);
    }

    /// Vector length squared. Less computationally expensive than length().
    pub inline fn lengthSquared(self: Vec3) BaseFloat {
        return self._x * self._x + self._y * self._y + self._z * self._z;
    }

    /// Vector length.
    pub inline fn length(self: Vec3) BaseFloat {
        return math.sqrt(self.lengthSquared());
    }

    /// Create an unit vector from v.
    /// If v is zero length, returns a Vec3 full of NaNs.
    pub inline fn unitVector(v: Vec3) Vec3 {
        // TODO divide by zero
        const len = v.length();
        return Vec3.init(v._x / len, v._y / len, v._z / len);
    }

    pub inline fn negate(self: Vec3) Vec3 {
        return Vec3.init(-self._x, -self._y, -self._z);
    }

    pub inline fn plus(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self._x + other._x, self._y + other._y, self._z + other._z);
    }

    pub inline fn minus(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self._x - other._x, self._y - other._y, self._z - other._z);
    }

    pub inline fn plusScalar(self: Vec3, scalar: BaseFloat) Vec3 {
        return Vec3.init(self._x + scalar, self._y + scalar, self._z + scalar);
    }

    pub inline fn minusScalar(self: Vec3, scalar: BaseFloat) Vec3 {
        return Vec3.init(self._x - scalar, self._y - scalar, self._z - scalar);
    }

    pub inline fn scale(self: Vec3, scalar: BaseFloat) Vec3 {
        return Vec3.init(self._x * scalar, self._y * scalar, self._z * scalar);
    }

    pub inline fn multiply(self: Vec3, scalar: BaseFloat) Vec3 {
        return Vec3.init(self._x * scalar, self._y * scalar, self._z * scalar);
    }

    /// Divide vector by scalar.
    /// If scalar is 0, then result is Vec3 full of NaNs.
    pub inline fn divide(self: Vec3, scalar: BaseFloat) Vec3 {
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

    /// Returns a center point for a list of vectors
    pub fn center(vectors: ArrayList(Vec3)) Vec3 {
        const len_scale = 1.0 / @intToFloat(BaseFloat, vectors.items.len);
        var x_sum: BaseFloat = 0.0;
        var y_sum: BaseFloat = 0.0;
        var z_sum: BaseFloat = 0.0;
        for (vectors.items) |*vector, i| {
            x_sum += vector._x * len_scale;
            y_sum += vector._y * len_scale;
            z_sum += vector._z * len_scale;
        }
        return Vec3.init(x_sum, y_sum, z_sum);
    }

    /// Generate random vector where each coordinate is between min and max.
    pub inline fn random_vector(random: *Random, min: BaseFloat, max: BaseFloat) Vec3 {
        var r = DefaultPrng.init(0).random;
        const x_val = random.float(BaseFloat) * 2.0 - 1.0;
        const y_val = random.float(BaseFloat) * 2.0 - 1.0;
        const z_val = random.float(BaseFloat) * 2.0 - 1.0;
        return Vec3.init(x_val, y_val, z_val);
    }

    /// Generate random vector that is inside a unit sphere.
    /// Uniformly distributed random vector whose length is <= 1.0.
    pub inline fn randomVectorInUnitSphere(random: *Random) Vec3 {
        while (true) {
            const p = Vec3.random_vector(random, -1.0, 1.0);
            if (Vec3.lengthSquared(p) > 1.0) {
                continue;
            }
            return p;
        }
        return unreachable;
    }

    // Generate a random uniformly distributed unit vector.
    pub inline fn randomUnitVector(random: *Random) Vec3 {
        while (true) {
            const p = randomVectorInUnitSphere(random);
            const unit_p = Vec3.unitVector(p);
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

test "Vec3.init()" {
    const my_x: BaseFloat = 1.0;
    const my_y: BaseFloat = 2.0;
    const my_z: BaseFloat = 3.0;
    const vec = Vec3.init(my_x, my_y, my_z);

    expectEqual(my_x, vec.x());
    expectEqual(my_y, vec.y());
    expectEqual(my_z, vec.z());

    expectEqual(my_x, vec.elem(0));
    expectEqual(my_y, vec.elem(1));
    expectEqual(my_z, vec.elem(2));
}

test "Vec3.dot()" {
    const vec_0 = Vec3.init(0.0, 0.0, 0.0);
    const vec_unit_x = Vec3.init(1.0, 0.0, 0.0);
    const vec_unit_y = Vec3.init(0.0, 1.0, 0.0);
    const vec_unit_z = Vec3.init(0.0, 0.0, 1.0);
    expectEqual(@as(BaseFloat, 0.0), vec_0.dot(vec_unit_x));

    expectEqual(@as(BaseFloat, 0.0), vec_unit_x.dot(vec_unit_y));
    expectEqual(@as(BaseFloat, 0.0), vec_unit_x.dot(vec_unit_z));
    expectEqual(@as(BaseFloat, 0.0), vec_unit_y.dot(vec_unit_z));

    expectEqual(@as(BaseFloat, 1.0), vec_unit_x.dot(vec_unit_x));
    expectEqual(@as(BaseFloat, 1.0), vec_unit_y.dot(vec_unit_y));
    expectEqual(@as(BaseFloat, 1.0), vec_unit_z.dot(vec_unit_z));
}

test "Vec3.unitVector() with zero length vector" {
    const vec_0 = Vec3.init(0.0, 0.0, 0.0);
    const zero_unit = vec_0.unitVector();
    expect(math.isNan(zero_unit.x()));
    expect(math.isNan(zero_unit.y()));
    expect(math.isNan(zero_unit.z()));
}

test "Vec3.unitVector() with non-zero length vector" {
    const vec_1 = Vec3.init(1.0, 0.0, 0.0);
    const vec_2 = Vec3.init(3.0, -4.0, 0.0);
    expectEqual(vec_1, vec_1.unitVector());
    expectEqual(Vec3.init(0.6, -0.8, 0.0), vec_2.unitVector());
}


test "Vec3.center with zero vectors" {
    const allocator = std.heap.page_allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();

    const center_vector = Vec3.center(list);
    expectEqual(@as(BaseFloat, 0.0), center_vector.x());
    expectEqual(@as(BaseFloat, 0.0), center_vector.y());
    expectEqual(@as(BaseFloat, 0.0), center_vector.z());
}

test "Vec3.center() with one vectors" {
    const allocator = std.heap.page_allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();

    const vec1 = Vec3.init(1.0, 2.0, 4.0);
    try list.append(vec1);
    const center_vector = Vec3.center(list);
    expectEqual(@as(BaseFloat, 1.0), center_vector.x());
    expectEqual(@as(BaseFloat, 2.0), center_vector.y());
    expectEqual(@as(BaseFloat, 4.0), center_vector.z());
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
    expectEqual(@as(BaseFloat, -1.0), center_vector.x());
    expectEqual(@as(BaseFloat, 2.0), center_vector.y());
    expectEqual(@as(BaseFloat, -4.0), center_vector.z());
}

test "Vec3.random_vector()" {
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

test "Vec3.randomInUnitSphere()" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const vector = Vec3.randomVectorInUnitSphere(random);

    const expected = Vec3.init(0.1846, 0.8305, -0.0479);
    expect(math.absFloat(expected.x() - vector.x()) < 0.01);
    expect(math.absFloat(expected.y() - vector.y()) < 0.01);
    expect(math.absFloat(expected.z() - vector.z()) < 0.01);
    expect(Vec3.length(vector) < 1.0);
}

test "Vec3.randomUnitVector()" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const vector = Vec3.randomUnitVector(random);
    const expected = Vec3.init(0.2167, 0.9746, -0.0562);
    expect(math.absFloat(expected.x() - vector.x()) < 0.01);
    expect(math.absFloat(expected.y() - vector.y()) < 0.01);
    expect(math.absFloat(expected.z() - vector.z()) < 0.01);
    expect(Vec3.length(vector) < 1.01);
    expect(Vec3.length(vector) > 0.99);
}
