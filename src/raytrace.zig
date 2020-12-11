const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;
const math = std.math;
const ArrayList = std.ArrayList;
const BaseFloat = @import("base.zig").BaseFloat;
const Vec3 = @import("vector.zig").Vec3;
usingnamespace @import("ray.zig");
const img = @import("image.zig");
const Image = img.Image;
const Color = img.Color;
const HitRecord = @import("hit_record.zig").HitRecord;
const Camera = @import("camera.zig").Camera;
const Material = @import("material.zig").Material;
const Texture = @import("texture.zig").Texture;
const Surface = @import("surface.zig").Surface;
usingnamespace @import("bvh.zig");


const Progress = struct {
    start_time: i64,
    scanline_start_time: i64,
    recursion_depth_hits: u64 = 0.0,
    reflections: u64 = 0.0,
    background_hits: u64 = 0.0,
    pixels_processed: u64 = 0.0,
    samples_processed: u64 = 0.0,
    rays_processed: u64 = 0.0,

    pub fn init(start_time: i64) Progress {
        return .{.start_time = start_time,
                 .scanline_start_time = start_time, };
    }
};

/// Print progress to stdout
fn printProgress(scanline: u64, total_scanlines: u64, progress: *Progress, progress_prev: *Progress) void {
    const pixel_change = progress.pixels_processed - progress_prev.pixels_processed;
    const time_diff = @intToFloat(f32, std.time.milliTimestamp() - progress.scanline_start_time) / 1000.;
    const pixels_per_second = @intToFloat(f32, pixel_change) / time_diff;
    std.debug.warn("Scanline: {}/{} Pixels: {} Samples: {} Rays: {} Recursion limit: {} Reflections: {} Background hits: {} Pixels/s: {d:0.1}\n",
                   .{
                       scanline, total_scanlines,
                       progress.pixels_processed, progress.samples_processed, progress.rays_processed,
                       (progress.recursion_depth_hits - progress_prev.recursion_depth_hits),
                       (progress.reflections - progress_prev.reflections),
                       (progress.background_hits - progress_prev.background_hits),
                       pixels_per_second,
                   });
}

/// Background color for rays that do not hit anything
inline fn backgroundColor(ray: *const Ray) Color {
    const unit_direction = ray.direction.unitVector();
    const t = 0.5 * (unit_direction.y() + 1.0);
    return Color.white.scale(1.0-t)
            .add(Color.init(0.5, 0.7, 1.0).scale(t));
}

// TODO optimization: pass in empty hit_record where everything fills data
// More efficient to pass a pointer around?
fn rayColor(ray: *const Ray, surfaces: ArrayList(Surface), depth: u32, progress: *Progress) Color {
    // TODO use russian roulette to conditionally to continue
    if (depth <= 0) {
        // ray has been reflecting many times before hitting anything
        progress.recursion_depth_hits += 1;
        return Color.black;
    }
    progress.*.rays_processed += 1;

    var t_min: BaseFloat = 0.001;
    var t_max = math.inf(BaseFloat);
    var closest_hit: ?HitRecord = null;
    // loop over the surfaces and check if the ray hits any of them
    for (surfaces.items) |*surface, index| {
        const current_hit_record = surface.hit(ray, t_min, t_max);
        if (current_hit_record != null) {
            closest_hit = current_hit_record.?;
            t_max = closest_hit.?.t;
        }
    }
    if (closest_hit == null) {
        // ray hits the background
        progress.background_hits += 1;
        return backgroundColor(ray);
    }
    const hit_record = closest_hit.?;
    const hit_surface = hit_record.surface;
    const material = hit_surface.material();
    const potential_scattering = material.scatter(ray, hit_record);
    if (potential_scattering == null) {
        // material fully absorbed the ray
        return Color.black;
    }
    progress.reflections += 1;

    const scattering = potential_scattering.?;
    // material reflected the ray
    return scattering.attenuation.multiply(rayColor(&scattering.scattered_ray, surfaces, depth - 1, progress));
}

pub const RenderParams = struct {
    width: u16,
    height: u16,
    samples_per_pixel: u16,
    max_depth: u16,
    bounded_volume_hierarchy: bool = true,
};

// TODO use ArrayList(*Surface) everywhere (or SurfaceList)
fn boundedVolumeHierarchy(allocator: *Allocator, random: *Random, surfaces: ArrayList(Surface)) ! ArrayList(Surface) {
    var surface_pointers = ArrayList(*Surface).init(allocator);
    defer surface_pointers.deinit();
    for (surfaces.items) |*surface| {
        try surface_pointers.append(surface);
    }
    const bvh_root = try BVHNode.init(allocator, random, &surface_pointers);
    var result = ArrayList(Surface).init(allocator);
    try result.append(Surface.initBVHNode(bvh_root));
    return result;
}

// TODO make a SurfaceList abstraction
fn preprocessSufraces(allocator: *Allocator, random: *Random,
                        surfaces: ArrayList(Surface), render_params: RenderParams) ! ArrayList(Surface) {
    // BVH makes things faster only with large number of surfaces
    if (render_params.bounded_volume_hierarchy and surfaces.items.len > 10) {
        std.debug.warn("Using Bounded Volume Hierarchy\n", .{});
        return boundedVolumeHierarchy(allocator, random, surfaces);
    }
    std.debug.warn("Using surface list\n", .{});
    return surfaces;
}

/// Render a scene
pub fn render(allocator: *Allocator, random: *Random,
                camera: Camera, surfaces: ArrayList(Surface),
                render_params: RenderParams,) ! *Image {
    var start_time = std.time.milliTimestamp();
    var progress = Progress.init(start_time);
    var progress_prev = Progress.init(start_time);

    std.debug.warn("Raytrace start\n", .{});
    std.debug.warn(" - Surfaces:                 {}\n", .{surfaces.items.len});
    std.debug.warn(" - Pixels:                   {}x{}\n", .{render_params.width, render_params.height});
    std.debug.warn(" - Samples per pixel:        {}\n", .{render_params.samples_per_pixel});
    std.debug.warn(" - Recursion depth:          {}\n", .{render_params.max_depth});
    std.debug.warn(" - Bounded volume hierarchy: {}\n", .{render_params.bounded_volume_hierarchy});

    const processed_surfaces = try preprocessSufraces(allocator, random, surfaces, render_params);

    var image = try Image.init(allocator, render_params.width, render_params.height);

    const f_width = @intToFloat(BaseFloat, render_params.width);
    const f_height = @intToFloat(BaseFloat, render_params.height);

    var color_acc = Color.newBlack();
    const color_scale = 1.0 / @intToFloat(f32, render_params.samples_per_pixel);
    const render_start_time = std.time.milliTimestamp();

    // loop over every pixel on the screen
    var y: usize = 0;
    while (y < image.height) : (y += 1) {
        const f_y = @intToFloat(BaseFloat, y);

        var x: usize = 0;
        const image_offset_y = y * render_params.width;
        while (x < image.height) : (x += 1) {
            color_acc.setMutate(Color.newBlack());
            // send several sample rays per pixel
            var sample: usize = 0;
            while (sample < render_params.samples_per_pixel) : (sample += 1) {
                const u = (@intToFloat(BaseFloat, x) + random.float(BaseFloat) - 0.5) / f_width;
                const v = (f_y + random.float(BaseFloat) - 0.5) / f_height;
                const ray = camera.getRay(u, v);
                const color = rayColor(&ray, processed_surfaces, render_params.max_depth, &progress);
                color_acc.addMutate(color);
                progress.samples_processed += 1;
            }
            const image_offset = image_offset_y + x;
            progress.pixels_processed += 1;
            image.pixels[image_offset] = color_acc.scale(color_scale);
        }
        printProgress(y + 1, render_params.height, &progress, &progress_prev);
        progress_prev = progress;
        progress.scanline_start_time = std.time.milliTimestamp();
    }
    const end_time = std.time.milliTimestamp();
    const render_runtime = @intToFloat(f32, end_time - render_start_time) / 1000.0; 
    const runtime = @intToFloat(f32, end_time - progress.start_time) / 1000.0;
    std.debug.warn("Rendering ready\n", .{});
    std.debug.warn("  Total reflections:     {}\n", .{progress.reflections});
    std.debug.warn("  Total background hits: {}\n", .{progress.background_hits});
    std.debug.warn("  Total pixels:          {}\n", .{progress.pixels_processed});
    std.debug.warn("  Total samples:         {}\n", .{progress.samples_processed});
    std.debug.warn("  Total rays:            {}\n", .{progress.rays_processed});
    std.debug.warn("  Total reflections:     {}\n", .{progress.reflections});
    std.debug.warn("  Pixels per second:     {d:0.2} pixels/s\n", .{@intToFloat(f32, progress.pixels_processed) / runtime});
    std.debug.warn("  Total runtime:         {d:0.2} seconds\n", .{runtime});
    std.debug.warn("    Prepare runtime:     {d:0.2} seconds\n", .{runtime - render_runtime});
    std.debug.warn("    Render runtime:      {d:0.2} seconds\n", .{render_runtime});
    return image;
}


//// Testing
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const ppm_image = @import("ppm_image.zig");
const Metal = @import("material.zig").Metal;
const Lambertian = @import("material.zig").Lambertian;
const Sphere = @import("sphere.zig").Sphere;

test "Render something" {
    const camera = Camera.init(Vec3.init(0.0, 0.0, -7.), Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var objects = ArrayList(Surface).init(allocator);
    defer objects.deinit();
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    const gold_metal = Material.initMetal(Metal.init(Texture.initColor(Color.gold)));
    const green_matte = Material.greenMatte(random);
    const purple_matte = Material.initLambertian(Lambertian.init(random, Texture.initColor(Color.init(0.5, 0., 0.5))));

    // TODO this copies the materials with objects
    try objects.append(Surface.initSphere(Sphere.init(Vec3.z_unit.scale(6), 2.0, &gold_metal)));
    try objects.append(Surface.initSphere(Sphere.init(Vec3.init(3., 1, 4.0), 1.0, &purple_matte)));
    try objects.append(Surface.initSphere(Sphere.init(Vec3.init(1., 102.5, 4.0), 100.0, &green_matte)));

    const render_params = RenderParams{.width = 20, .height = 20, .samples_per_pixel = 5, .max_depth = 5,
                                        .bounded_volume_hierarchy = false};
    const scene_image = try render(allocator, random, camera, objects, render_params);
    defer scene_image.deinit();
    const foo = ppm_image.writeFile("./target/render_test.ppm", scene_image);
}

const ObjReader = @import("obj_reader.zig");

test "Render Man model" {
    const camera = Camera.init(Vec3.init(0.0, 0.0, -30.), Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var objects = ArrayList(Surface).init(allocator);
    defer objects.deinit();
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    const filename = "./models/man/Man.obj";
    const man_model = try ObjReader.readObjFile(allocator, filename, &Material.blue_metal);
    defer man_model.deinit();
    // objects
    const top: BaseFloat = -2.33;
    const radius: BaseFloat = 100.0;
    const earth_center = Vec3.init(1.66445508e-01, top - radius, 7.37018966e+00);

    try objects.append(Surface.initSphere(Sphere.init(earth_center, radius, &Material.greenMatte(random))));
    for (man_model.items) |surface| {
        try objects.append(surface);
    }
    const render_params = RenderParams{.width = 30, .height = 30, .samples_per_pixel = 5, .max_depth = 5,
                                        .bounded_volume_hierarchy = true};
    const scene_image = try render(allocator, random, camera, objects, render_params);
    defer scene_image.deinit();
    const foo = ppm_image.writeFile("./target/render_man.ppm", scene_image);
}
