const std = @import("std");
const math = std.math;
const Random = std.rand.Random;
const BaseFloat = @import("base.zig").BaseFloat;
const Vec3 = @import("vector.zig").Vec3;

pub const Sample = struct {

    /// Generate random vector where each coordinate is between min and max.
    pub inline fn randomVector(random: *Random, min: BaseFloat, max: BaseFloat) Vec3 {
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
            const p = Sample.randomVector(random, -1.0, 1.0);
            if (Vec3.lengthSquared(p) > 1.0) {
                continue;
            }
            return p;
        }
        return unreachable;
    }

    /// Generate a random uniformly distributed unit vector.
    pub inline fn randomUnitVector_old(random: *Random) Vec3 {
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

    /// http://www.rorydriscoll.com/2009/01/07/better-sampling/
    pub inline fn randomHemisphere(random: *Random) Vec3 {
        const r1: BaseFloat = random.float(BaseFloat);
        const r2: BaseFloat = random.float(BaseFloat);
        const r = math.sqrt(@as(BaseFloat, 1.0) - r1 * r1);
        const phi = 2.0 *  math.pi * r2;
        return Vec3.init(math.cos(phi) * r, math.sin(phi) * r, r1);
    }

    pub inline fn randomUnitVector(random: *Random) Vec3 {
        const v = randomHemisphere(random);
        if (random.boolean()) {
            return v;
        }
        return Vec3.init(v._x, v._y, v._z * -1.0);
    }
};

///// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const DefaultPrng = std.rand.DefaultPrng;


test "Vec3.randomVector()" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const vector = Sample.randomVector(random, -1.0, 1.0);

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
    const vector = Sample.randomVectorInUnitSphere(random);

    const expected = Vec3.init(0.1846, 0.8305, -0.0479);
    expect(math.absFloat(expected.x() - vector.x()) < 0.01);
    expect(math.absFloat(expected.y() - vector.y()) < 0.01);
    expect(math.absFloat(expected.z() - vector.z()) < 0.01);
    expect(Vec3.length(vector) < 1.0);
}

test "Vec3.randomUnitVector_old()" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const vector = Sample.randomUnitVector_old(random);
    const expected = Vec3.init(0.2167, 0.9746, -0.0562);
    expect(math.absFloat(expected.x() - vector.x()) < 0.01);
    expect(math.absFloat(expected.y() - vector.y()) < 0.01);
    expect(math.absFloat(expected.z() - vector.z()) < 0.01);
    expect(Vec3.length(vector) < 1.01);
    expect(Vec3.length(vector) > 0.99);
}

test "Vec3.randomUnitVector()" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const vector = Sample.randomUnitVector(random);
    const expected = Vec3.init(-0.344, -0.932, 0.113);
    expect(math.absFloat(expected.x() - vector.x()) < 0.01);
    expect(math.absFloat(expected.y() - vector.y()) < 0.01);
    expect(math.absFloat(expected.z() - vector.z()) < 0.01);
    expect(Vec3.length(vector) < 1.01);
    expect(Vec3.length(vector) > 0.99);
}


test "perf randomSphere()" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const start1 = std.time.milliTimestamp();
    var i: u64 = 0;
    while (i < 10) : (i += 1) {
        var a = Sample.randomUnitVector(random);
        // std.debug.warn("  {} {}\n", .{a, a.length()});
    }
    std.debug.warn("Took {} ms\n", .{std.time.milliTimestamp() - start1});
}

test "perf randomUnitVector()" {
    var prng = DefaultPrng.init(0);
    const random = &prng.random;
    const start1 = std.time.milliTimestamp();
    var i: u64 = 0;
    while (i < 10) : (i += 1) {
        var a = Sample.randomUnitVector_old(random);
        // std.debug.warn("  {} {}\n", .{a, a.length()});
    }
    std.debug.warn("Took {} ms\n", .{std.time.milliTimestamp() - start1});
}
