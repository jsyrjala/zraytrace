//! Materials
const std = @import("std");
const Random = std.rand.Random;
const Color = @import("image.zig").Color;
const Ray = @import("ray.zig").Ray;
const vector = @import("vector.zig");
const Vec2 = vector.Vec2;
const Vec3 = vector.Vec3;
const Sample = @import("Sample.zig").Sample;
const HitRecord = @import("hit_record.zig").HitRecord;
const Surface = @import("surface.zig").Surface;
const Texture = @import("texture.zig").Texture;

/// Material is "supertype" for all material types
pub const Material = union (enum) {
    /// Example materials
    pub const black_metal = initMetal(Metal.init(Texture.initColor(Color.black)));
    pub const silver_metal = initMetal(Metal.init(Texture.initColor(Color.silver)));
    pub const blue_metal = initMetal(Metal.init(Texture.initColor(Color.blue)));
    pub const green_metal = initMetal(Metal.init(Texture.initColor(Color.green)));

    pub fn greenMatte(random: *Random) Material {
        return initLambertian(Lambertian.init(random, Texture.initColor(Color.green)));
    }

    lambertian: Lambertian,
    metal: Metal,

    pub fn initMetal(metal: Metal) Material {
        return Material{.metal = metal};
    }
    pub fn initLambertian(lambertian: Lambertian) Material {
        return Material{.lambertian = lambertian};
    }
    /// Find the right material type and call it's scatter method
    pub inline fn scatter(material: Material, ray: *const Ray, hit_record: HitRecord) ?Scattering {
        const enum_fields = comptime std.meta.fields(@TagType(Material));
        inline for (std.meta.fields(Material)) |field, i| {
            if (@enumToInt(material) == enum_fields[i].value) {
                return @field(material, field.name).scatter(ray, hit_record);
            }
        }
        unreachable;
    }
};

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
    texture: Texture,

    pub fn init(random: *Random, texture: Texture) Lambertian {
        return .{.random = random, .texture = texture};
    }

    pub inline fn scatter(material: Lambertian, ray: *const Ray, hit_record: HitRecord) ?Scattering {
        const scatter_direction = hit_record.normal
                                    .plus(Sample.randomUnitVector(material.random));
        const scattered = Ray.init(hit_record.location, scatter_direction);
        return Scattering.init(scattered, material.texture.albedo(hit_record.texture_coords, hit_record.location));
    }
};

/// Metal material
pub const Metal = struct {
    texture: Texture,

    pub fn init(texture: Texture) Metal {
        return .{.texture = texture};
    }

    pub inline fn scatter(material: Metal, ray: *const Ray, hit_record: HitRecord) ?Scattering {
        const reflected = ray.direction.unitVector().reflect(hit_record.normal);
        const scattered = Ray.init(hit_record.location, reflected);
        const produce_ray = scattered.direction.dot(hit_record.normal) > 0;
        if (produce_ray) {
            return Scattering.init(scattered, material.texture.albedo(hit_record.texture_coords, hit_record.location));
        }
        return null;
    }
};

//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Sphere = @import("sphere.zig").Sphere;

test "Material.scatter()" {
    const metal = Metal.init(Texture.initColor(Color.black));
    const material = &Material.initMetal(metal);
    const ray = Ray.init(Vec3.origin, Vec3.z_unit);
    var surface = Surface.initSphere(Sphere.init(Vec3.z_unit, 10.0, material));

    const hit = HitRecord.init(&ray, Vec3.z_unit.scale(2.0), Vec3.y_unit, 10.0, &surface, Vec2.origin);
    const scattering = material.scatter(&ray, hit);
}

test "Lambertian.init()" {
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;
    const material = &Lambertian.init(random, Texture.initColor(Color.black));
}

test "Lambertian.scatter()" {
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;
    const lambertian = Lambertian.init(random, Texture.initColor(Color.black));
    const material = &Material.initLambertian(lambertian);
    var surface = Surface.initSphere(Sphere.init(Vec3.z_unit, 10.0, material));

    const ray = Ray.init(Vec3.origin, Vec3.z_unit);
    const hit = HitRecord.init(&ray, Vec3.z_unit.scale(2.0), Vec3.y_unit, 10.0, &surface, Vec2.origin);
    const scattering = material.scatter(&ray, hit);
}

test "Metal.init()" {
    const material = Metal.init(Texture.initColor(Color.black));
}

test "Metal.scatter()" {
    const metal = Metal.init(Texture.initColor(Color.black));
    const material = &Material.initMetal(metal);
    const ray = Ray.init(Vec3.origin, Vec3.z_unit);
    const surface = Surface.initSphere(Sphere.init(Vec3.z_unit, 10.0, material));

    const hit = HitRecord.init(&ray, Vec3.z_unit.scale(2.0), Vec3.y_unit, 10.0, &surface, Vec2.origin);
    const scattering = material.scatter(&ray, hit);
}
