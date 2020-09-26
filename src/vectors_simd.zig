const std = @import("std");
const meta = std.meta;
//
// const Vector = meta.Vector;
const eql = meta.eql;
const math = std.math;
const Random = std.rand.Random;
const DefaultPrng = std.rand.DefaultPrng;
const ArrayList = std.ArrayList;

// https://ziglearn.org/chapter-1/#vectors


const Vec3 = @Vector(3, f32);

pub fn newVec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3{x, y, z};
}

pub inline fn dot(self: Vec3, other: Vec3) f32 {
    return self[0] * other[0] + self[1] * other[1] + self[2] * other[2];
}

pub inline fn cross(u: Vec3, v: Vec3) Vec3 {
    return newVec3(u[1] * v[2] - u[2] * v[1],
                   u[2] * v[0] - u[0] * v[2],
                   u[0] * v[1] - u[1] * v[0]);
}

pub inline fn length_squared(u: Vec3) f32 {
    return u[0] * u[0] + u[1] * u[1] + u[2] * u[2];
}

pub inline fn length(u: Vec3) f32 {
    return math.sqrt(length_squared(u));
}

pub inline fn unit_vector(u: Vec3) Vec3 {
    const len = length(u);
    return newVec3(u[0] / len, u[1] / len, u[2] / len);
}

pub inline fn negate(u: Vec3) Vec3 {
    return -u;
}

pub fn center(vectors: ArrayList(Vec3)) Vec3 {
    const len_scale = 1.0 / @intToFloat(f32, vectors.items.len);
    var x_sum: f32 = 0.0;
    var y_sum: f32 = 0.0;
    var z_sum: f32 = 0.0;
    for (vectors.items) |vector, i| {
        x_sum += vector[0] * len_scale;
        y_sum += vector[1] * len_scale;
        z_sum += vector[2] * len_scale;
    }
    return newVec3(x_sum, y_sum, z_sum);
}

// testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "new" {
    expect(meta.eql(Vec3{1.0, 2.0, -3.1}, newVec3(1.0, 2.0, -3.1)));
}

test "+" {
    const vec1 = newVec3(1.0, 2.0, 3.0);
    const vec2 = newVec3(3.0, 1.0, 99.0);
    const sum = vec1 + vec2;
    expect(meta.eql(Vec3{4.0, 3.0, 102.0}, sum));
}

test "dot" {
    const vec1 = newVec3(1.0, 2.0, 3.0);
    const vec2 = newVec3(3.0, 1.0, 4.0);
    expectEqual(@as(f32, 17.0), dot(vec1, vec2));
}

test "cross" {
    const vec1 = newVec3(1.0, 0.0, 0.0);
    const vec2 = newVec3(0.0, 1.0, 0.0);
    const vec3 = newVec3(0.0, -1.0, 0.0);

    const expected1 = newVec3(0.0, 0.0, 1.0);
    expectEqual(expected1, cross(vec1, vec2));

    const expected2 = newVec3(0.0, 0.0, -1.0);
    expectEqual(expected2, cross(vec1, vec3));
}

test "length_squared()" {
    const vec1 = newVec3(2.0, 0., 0.);
    expectEqual(@as(f32, 4.0), length_squared(vec1));
}

test "length()" {
    const vec1 = newVec3(3.0, 4., 0.);
    expectEqual(@as(f32, 5.0), length(vec1));
}

test "unit_vector() with zero vector" {
    const vec_0 = newVec3(0., 0., 0.);
    const zero_unit = unit_vector(vec_0);

    expect(math.isNan(zero_unit[0]));
    expect(math.isNan(zero_unit[1]));
    expect(math.isNan(zero_unit[2]));
}

test "unit_vector() with non-zero vector" {
    const vec = newVec3(4., -3., 0.);
    const unit = unit_vector(vec);
    const expected = newVec3(0.8, -0.6, 0.0);
    expectEqual(expected, unit);
}

test "negate()" {
    const vec = newVec3(4., -3., 0.1);
    const negated = -vec;
    const expected = newVec3(-4., 3., -0.1);
    expectEqual(expected, negated);
    expectEqual(expected, negate(vec));
}

test "center() with no vectors" {
    const allocator = std.heap.page_allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();
    const center_vector = center(list);
    expectEqual(newVec3(0., 0., 0.), center_vector);
}

test "center() with three vectors" {
    const allocator = std.heap.page_allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();
    const vec1 = newVec3(1.0, 2.0, 4.0);
    const vec2 = newVec3(-1.0, -2.0, -4.0);
    const vec3 = newVec3(-3.0, 6.0, -12.0);
    try list.append(vec1);
    try list.append(vec2);
    try list.append(vec3);
    const center_vector = center(list);
    expectEqual(newVec3(-1., 2., -4.), center_vector);
}
