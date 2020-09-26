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

///// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const DefaultPrng = std.rand.DefaultPrng;

test "Vec3.dot" {
    const vec_0 = Vec3.init(0.0, 0.0, 0.0);
    const vec_unit_x = Vec3.init(1.0, 0.0, 0.0);
    const vec_unit_y = Vec3.init(0.0, 1.0, 0.0);
    expectEqual(@as(Vec3Float, 0.0), vec_0.dot(vec_unit_x));
    expectEqual(@as(Vec3Float, 0.0), vec_unit_x.dot(vec_unit_y));
    expectEqual(@as(Vec3Float, 1.0), vec_unit_x.dot(vec_unit_x));
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
    expectEqual(@as(Vec3Float, 0.0), center_vector.x());
    expectEqual(@as(Vec3Float, 0.0), center_vector.y());
    expectEqual(@as(Vec3Float, 0.0), center_vector.z());
}

test "Vec3.center() with one vectors" {
    const allocator = std.heap.page_allocator;
    var list = ArrayList(Vec3).init(allocator);
    defer list.deinit();

    const vec1 = Vec3.init(1.0, 2.0, 4.0);
    try list.append(vec1);
    const center_vector = Vec3.center(list);
    expectEqual(@as(Vec3Float, 1.0), center_vector.x());
    expectEqual(@as(Vec3Float, 2.0), center_vector.y());
    expectEqual(@as(Vec3Float, 4.0), center_vector.z());
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
    expectEqual(@as(Vec3Float, -1.0), center_vector.x());
    expectEqual(@as(Vec3Float, 2.0), center_vector.y());
    expectEqual(@as(Vec3Float, -4.0), center_vector.z());
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
