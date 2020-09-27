const std = @import("std");
const Random = std.rand.Random;
const Color = @import("image.zig").Color;
const Ray = @import("ray.zig").Ray;
const vector = @import("vector.zig");
const Vec3 = vector.Vec3;
const HitRecord = @import("hit_record.zig").HitRecord;

pub const Scattering = struct {
    scattered_ray: Ray,
    attenuation: Color,
    pub inline fn init(ray: Ray, attenuation: Color) Scattering {
        return Scattering{.scattered_ray = ray, .attenuation = attenuation};
    }
};

/// Diffuse material
pub const Lambertian = struct {
    random: *Random,
    albedo: Color,

    pub inline fn init(random: *Random, color: Color) Lambertian {
        return .{.random = random, .albedo = color};
    }

    pub inline fn scatter(material: Lambertian, ray: Ray, hit_record: HitRecord) ?Scattering {
        const scatter_direction = hit_record.normal
                                    .plus(Vec3.random_unit_vector(material.random));
        const scattered = Ray.init(hit_record.location, scatter_direction);
        return Scattering.init(scattered, material.albedo);
    }
};

/// Metal material
pub const Metal = struct {
    albedo: Color,
    pub inline fn init(color: Color) Metal {
        return .{.albedo = color};
    }

    pub inline fn scatter(material: Metal, ray: Ray, hit_record: HitRecord) ?Scattering {
        const reflected = ray.direction.unit_vector().reflect(hit_record.normal);
        const scattered = Ray.init(hit_record.location, reflected);
        const produce_ray = scattered.direction.dot(hit_record.normal) > 0;
        if (produce_ray) {
            return Scattering.init(scattered, material.albedo);
        }
        return null;
    }
};

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Sphere = @import("sphere.zig").Sphere;

test "Lambertian.init()" {
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;
    const material = Lambertian.init(random, Color.black);
}

test "Lambertian.scatter()" {
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;
    const material = Lambertian.init(random, Color.black);
    const object = Sphere.init(Vec3.z_unit, 10.0, Metal.init(Color.black));

    const ray = Ray.init(Vec3.origin, Vec3.z_unit);
    const hit = HitRecord.init(ray, Vec3.z_unit.scale(2.0), Vec3.y_unit, 10.0, object);
    const scattering = material.scatter(ray, hit);
}

test "Metal.init()" {
    const material = Metal.init(Color.black);
}

test "Metal.scatter()" {
    const material = Metal.init(Color.black);
    const ray = Ray.init(Vec3.origin, Vec3.z_unit);
    const object = Sphere.init(Vec3.z_unit, 10.0, material);

    const hit = HitRecord.init(ray, Vec3.z_unit.scale(2.0), Vec3.y_unit, 10.0, object);
    const scattering = material.scatter(ray, hit);
}
