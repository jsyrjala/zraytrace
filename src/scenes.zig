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
const Texture = @import("texture.zig").Texture;
const material = @import("material.zig");
const Material = material.Material;
const Metal = material.Metal;
const Lambertian = material.Lambertian;

const Camera = @import("camera.zig").Camera;
const Surface = @import("surface.zig").Surface;
const ObjReader = @import("obj_reader.zig");
const raytrace = @import("raytrace.zig");
const png_image = @import("png_image.zig");


pub fn manAndBall(allocator: *std.mem.Allocator, render_params: raytrace.RenderParams) ! *Image {
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

    try surfaces.append(Surface.initSphere(Sphere.init(earth_center, radius, &Material.greenMatte(random))));
    for (man_model.items) |surface| {
        try surfaces.append(surface);
    }
    const camera = Camera.init(Vec3.init(0.0, 0.0, -30.), Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    return raytrace.render(allocator, random, camera, surfaces, render_params);
}

pub fn threeBalls(allocator: *std.mem.Allocator, render_params: raytrace.RenderParams) ! *Image {
    std.debug.warn("Rendering scene Three balls\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const tmp_allocator = &arena.allocator;

    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    var surfaces = ArrayList(Surface).init(tmp_allocator);
    defer surfaces.deinit();

    const earthmap_image = try png_image.readFile(tmp_allocator, "./models/images/earthmap.png");
    const nitor_image = try png_image.readFile(tmp_allocator, "./models/images/nitor-logo-25.png");

    const gold_metal = Material.initMetal(Metal.init(Texture.initColor(Color.gold)));
    const earth_metal = Material.initMetal(Metal.init(Texture.initImage(nitor_image)));
    const green_matte = Material.greenMatte(random);

    //const purple_matte = Material.initLambertian(Lambertian.init(random, Texture.initColor(Color.init(0.5, 0., 0.5))));
    const purple_matte = Material.initLambertian(Lambertian.init(random, Texture.initImage(earthmap_image)));

    try surfaces.append(Surface.initSphere(Sphere.init(Vec3.z_unit.scale(8), 2.0, &earth_metal)));
    try surfaces.append(Surface.initSphere(Sphere.init(Vec3.init(3., -1, 4.0), 1.5, &purple_matte)));
    try surfaces.append(Surface.initSphere(Sphere.init(Vec3.init(1., -102.5, 4.0), 100.0, &green_matte)));

    const camera = Camera.init(Vec3.init(0.0, 0.0, -7.), Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    return try raytrace.render(allocator, random, camera, surfaces, render_params);
}

pub fn bunnyAndBall(allocator: *std.mem.Allocator, render_params: raytrace.RenderParams) ! *Image {
    std.debug.warn("Rendering scene Bunny and a big ball\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const tmp_allocator = &arena.allocator;

    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    var surfaces = ArrayList(Surface).init(tmp_allocator);
    defer surfaces.deinit();

    const filename = "./models/bunny/bunny.obj";
    const man_model: ArrayList(Surface) = try ObjReader.readObjFile(allocator, filename, &Material.silver_metal);
    defer man_model.deinit();

    const top: BaseFloat = -0.33;
    const radius: BaseFloat = 100.0;
    const earth_center = Vec3.init(1.66445508e-01, top - radius, 7.37018966e+00);

    try surfaces.append(Surface.initSphere(Sphere.init(earth_center, radius, &Material.greenMatte(random))));
    for (man_model.items) |surface| {
        try surfaces.append(surface);
    }
    const camera = Camera.init(Vec3.init(0.0, 0.0, -0.5), Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    return raytrace.render(allocator, random, camera, surfaces, render_params);
}

// $ zig build run -Drelease-fast=true --  700 700 500 20 4 images/image-4.pnn
// raytrace
// USAGE;
// raytrace width heigth samples depth scene_index filename
// Rendering scene Bunny and a circle of balls
// Reading OBJ model from ./models/teapot/teapot.obj
// Found
//   center point:   Vec3(0.054,1.724,-0.000)
//   bounding box:   AABB(Min(-3.000,0.000,-2.000),Max(3.434,3.150,2.000))
//   vertexes:       3644
//   vertex normals: 0
//   faces:          6320
//   triangles:      6320
//   surfaces:       6320
// Raytrace start
//  - Surfaces:                 6323
//  - Pixels:                   700x700
//  - Samples per pixel:        500
//  - Recursion depth:          20
//  - Bounded volume hierarchy: true
// Using Bounded Volume Hierarchy
// Computing Bounded Volume Hierarchy for 6323 surfaces
// Max depth in BVH is 13
// Scanline: 1/700 Pixels: 700 Samples: 350000 Rays: 728696 Recursion limit: 1 Reflections: 378697 Background hits: 349999 Pixels/s: 41.2
// ...
// Scanline: 700/700 Pixels: 490000 Samples: 245000000 Rays: 425784511 Recursion limit: 0 Reflections: 0 Background hits: 350000 Pixels/s: 4.5
// Rendering ready
//   Total reflections:     180786957
//   Total background hits: 244997554
//   Total pixels:          490000
//   Total samples:         245000000
//   Total rays:            425784511
//   Total reflections:     180786957
//   Pixels per second:     13.59 pixels/s
//   Total runtime:         36069.00 seconds
// Writing 490000 pixels to file images/image-4.pnn
// Wrote 0 bytes to file images/image-4.pnn

pub fn teapotAndBallCircle(allocator: *std.mem.Allocator, render_params: raytrace.RenderParams) ! *Image {
    std.debug.warn("Rendering scene Bunny and a circle of balls\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const tmp_allocator = &arena.allocator;

    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    var surfaces = ArrayList(Surface).init(tmp_allocator);
    defer surfaces.deinit();

    const gold_metal = Material.initMetal(Metal.init(Texture.initColor(Color.gold)));
    const green_matte = Material.greenMatte(random);

    const earthmap_image = try png_image.readFile(tmp_allocator, "./models/images/earthmap.png");

    const purple_matte = Material.initLambertian(Lambertian.init(random, Texture.initImage(earthmap_image)));

    const filename = "./models/teapot/teapot.obj";
    const model: ArrayList(Surface) = try ObjReader.readObjFile(allocator, filename, &Material.blue_metal);
    defer model.deinit();

    const top: BaseFloat = -2.33;
    const radius: BaseFloat = 100.0;
    const earth_center = Vec3.init(1.66445508e-01, top - radius, 7.37018966e+00);

    try surfaces.append(Surface.initSphere(Sphere.init(Vec3.z_unit.scale(6), -2.0, &Material.silver_metal)));
    try surfaces.append(Surface.initSphere(Sphere.init(Vec3.init(3., -1, 4.0), 1.0, &purple_matte)));

    try surfaces.append(Surface.initSphere(Sphere.init(earth_center, radius, &Material.greenMatte(random))));
    for (model.items) |surface| {
        try surfaces.append(surface);
    }
    const camera = Camera.init(Vec3.init(-8.0, 0.0, -10.), Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    return raytrace.render(allocator, random, camera, surfaces, render_params);
}

pub fn teapotAndBall(allocator: *std.mem.Allocator, render_params: raytrace.RenderParams) ! *Image {
    std.debug.warn("Rendering scene Bunny and a big ball\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const tmp_allocator = &arena.allocator;

    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    var surfaces = ArrayList(Surface).init(tmp_allocator);
    defer surfaces.deinit();

    const filename = "./models/teapot/teapot.obj";
    const man_model: ArrayList(Surface) = try ObjReader.readObjFile(allocator, filename, &Material.blue_metal);
    defer man_model.deinit();

    const top: BaseFloat = -2.33;
    const radius: BaseFloat = 100.0;
    const earth_center = Vec3.init(1.66445508e-01, top - radius, 7.37018966e+00);

    try surfaces.append(Surface.initSphere(Sphere.init(earth_center, radius, &Material.greenMatte(random))));
    for (man_model.items) |surface| {
        try surfaces.append(surface);
    }
    const camera = Camera.init(Vec3.init(0.0, 0.0, -10.), Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    return raytrace.render(allocator, random, camera, surfaces, render_params);
}



const SceneError = error {
    UnkownSceneIndex,
};

pub fn render_scene(allocator: *std.mem.Allocator, render_params: raytrace.RenderParams, scene_index: u16) ! *Image {
    switch(scene_index) {
        0 => return manAndBall(allocator, render_params),
        1 => return threeBalls(allocator, render_params),
        2 => return bunnyAndBall(allocator, render_params),
        3 => return teapotAndBall(allocator, render_params),
        4 => return teapotAndBallCircle(allocator, render_params),

        else => return SceneError.UnkownSceneIndex
    }
}

//// Testing
test "render scenes in low resolution" {
    var scene_index: u16 = 0;
    while (scene_index < 4) : (scene_index += 1) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = &arena.allocator;
        const render_params = raytrace.RenderParams{.width = 10, .height = 10, .samples_per_pixel = 2, .max_depth = 2};
        _ = try render_scene(allocator, render_params, scene_index);
    }
}
