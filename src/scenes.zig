const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;
const ArrayList = std.ArrayList;

const BaseFloat = @import("base.zig").BaseFloat;
const image = @import("image.zig");
const Image = image.Image;
const Color = image.Color;
const Vec3 = @import("vector.zig").Vec3;
const Sphere = @import("sphere.zig").Sphere;
const material = @import("material.zig");
const Material = material.Material;
const Metal = material.Metal;
const Lambertian = material.Lambertian;

const Camera = @import("camera.zig").Camera;
const Surface = @import("surface.zig").Surface;
const ObjReader = @import("obj_reader.zig");
const raytrace = @import("raytrace.zig");


pub fn man_and_ball(allocator: *std.mem.Allocator, render_params: raytrace.RenderParams) ! *Image {
    std.debug.warn("Rendering scene Man and a big ball\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const tmp_allocator = &arena.allocator;

    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    var surfaces = ArrayList(Surface).init(tmp_allocator);
    defer surfaces.deinit();

    const filename = "./models/man/Man.obj";
    const man_model: ArrayList(Surface) = try ObjReader.readObjFile(allocator, filename, &Material.blue_metal);
    defer man_model.deinit();

    const top: BaseFloat = -2.33;
    const radius: BaseFloat = 100.0;
    const earth_center = Vec3.init(1.66445508e-01, top - radius, 7.37018966e+00);

    try surfaces.append(Surface.initSphere(Sphere.init(earth_center, radius, Material.green_matte(random))));
    for (man_model.items) |surface| {
        try surfaces.append(surface);
    }
    const camera = Camera.init(Vec3.init(0.0, 0.0, -30.), Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    return raytrace.render(allocator, random, camera, surfaces, render_params);
}

pub fn three_balls(allocator: *std.mem.Allocator, render_params: raytrace.RenderParams) ! *Image {
    std.debug.warn("Rendering scene Three balls\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const tmp_allocator = &arena.allocator;

    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    var surfaces = ArrayList(Surface).init(tmp_allocator);
    defer surfaces.deinit();

    const black_metal = Material.initMetal(Metal.init(Color.black));
    const gold_metal = Material.initMetal(Metal.init(Color.gold));
    const red_metal = Material.initMetal(Metal.init(Color.red));
    const green_metal = Material.initMetal(Metal.init(Color.green));
    const blue_metal = Material.initMetal(Metal.init(Color.blue));
    const white_metal = Material.initMetal(Metal.init(Color.white));
    const silver_metal = Material.initLambertian(Lambertian.init(random, Color.silver));

    const green_matte = Material.initLambertian(Lambertian.init(random, Color.green));
    const purple_matte = Material.initLambertian(Lambertian.init(random, Color.init(0.5, 0., 0.5)));

    try surfaces.append(Surface.initSphere(Sphere.init(Vec3.z_unit.scale(6), -2.0, gold_metal)));
    try surfaces.append(Surface.initSphere(Sphere.init(Vec3.init(3., -1, 4.0), 1.0, purple_matte)));
    try surfaces.append(Surface.initSphere(Sphere.init(Vec3.init(1., -102.5, 4.0), 100.0, green_matte)));

    const camera = Camera.init(Vec3.init(0.0, 0.0, -7.), Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    return try raytrace.render(allocator, random, camera, surfaces, render_params);
}

const SceneError = error {
    UnkownSceneIndex,
};

pub fn render_scene(allocator: *std.mem.Allocator, render_params: raytrace.RenderParams, scene_index: u16) ! *Image {
    switch(scene_index) {
        0 => return man_and_ball(allocator, render_params),
        1 => return three_balls(allocator, render_params),
        else => return SceneError.UnkownSceneIndex
    }
}

test "man_and_ball" {
    const render_params = raytrace.RenderParams{.width = 10, .height = 10, .samples_per_pixel = 2, .max_depth = 2};
    _ = try man_and_ball(render_params);
}
