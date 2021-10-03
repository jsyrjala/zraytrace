//! Materials
const std = @import("std");
const BaseFloat = @import("base.zig").BaseFloat;
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
    dielectric: Dielectric,

    pub fn initMetal(metal: Metal) Material {
        return Material{.metal = metal};
    }
    pub fn initLambertian(lambertian: Lambertian) Material {
        return Material{.lambertian = lambertian};
    }
    pub fn initDielectric(dielectric: Dielectric) Material {
        return Material{.dielectric = dielectric};
    }

// TODO use pointers
    /// Find the right material type and call it's scatter method
    pub inline fn scatter(material: Material, ray: *const Ray, hit_record: HitRecord) ?Scattering {
        const enum_fields = comptime std.meta.fields(std.meta.Tag(Material));
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
        // TODO already unit vector?
        const reflected = ray.direction.unitVector().reflect(hit_record.normal);
        const scattered = Ray.init(hit_record.location, reflected);
        const produce_ray = scattered.direction.dot(hit_record.normal) > 0;
        if (produce_ray) {
            return Scattering.init(scattered, material.texture.albedo(hit_record.texture_coords, hit_record.location));
        }
        return null;
    }
};

/// Dielectric material (glass etc)
pub const Dielectric = struct {
    random: *Random,
    index_of_refraction: BaseFloat,

    pub fn init(random: *Random, index_of_refraction: BaseFloat) Dielectric {
        return .{.random = random, .index_of_refraction = index_of_refraction};
    }

    /// https://raytracing.github.io/books/RayTracingInOneWeekend.html#dielectrics/schlickapproximation
    pub inline fn scatter(self: Dielectric, ray: *const Ray, hit_record: HitRecord) ?Scattering {
        const attenuation = Color.init(1.0, 1.0, 1.0);
        const refraction_ratio = if (hit_record.front_face) (1.0/self.index_of_refraction) else self.index_of_refraction;
        // TODO is already unit vector?
        const unit_direction = ray.direction.unitVector();
        const cos_theta = std.math.min(unit_direction.negate().dot(hit_record.normal), 1.0);
        const sin_theta = std.math.sqrt(1.0 - cos_theta * cos_theta);
        const cannot_refract = refraction_ratio * sin_theta > 1.0;
        if (cannot_refract or reflectance(cos_theta, refraction_ratio) > self.random.float(BaseFloat)) {
            const direction = unit_direction.reflect(hit_record.normal);
            return Scattering.init(Ray.init(hit_record.location, direction), attenuation);
        }
        const direction = unit_direction.refract(hit_record.normal, refraction_ratio);
        return Scattering.init(Ray.init(hit_record.location, direction), attenuation);
    }

    fn reflectance(cosine: BaseFloat, ref_idx: BaseFloat) f64 {
        const r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
        return r0 + (1.0 - r0) * std.math.pow(BaseFloat, 1 - cosine, 5.0);
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

test "Dielectric.init()" {
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;
    const material = Dielectric.init(random, 0.2);
}

test "Dielectric.scatter()" {
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;
    const dielectric = Dielectric.init(random, 0.2);
    const material = Material.initDielectric(dielectric);

    const ray = Ray.init(Vec3.origin, Vec3.z_unit);
    var surface = Surface.initSphere(Sphere.init(Vec3.z_unit, 10.0, &material));
    const hit = HitRecord.init(&ray, Vec3.z_unit.scale(2.0), Vec3.y_unit, 10.0, &surface, Vec2.origin);
    const scattering = material.scatter(&ray, hit);
}

