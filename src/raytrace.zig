const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;
const math = std.math;
const ArrayList = std.ArrayList;
const BaseFloat = @import("base.zig").BaseFloat;
const Vec3 = @import("vector.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const img = @import("image.zig");
const Image = img.Image;
const Color = img.Color;
const HitRecord = @import("hit_record.zig").HitRecord;
const Camera = @import("camera.zig").Camera;
const Material = @import("material.zig").Material;
const Surface = @import("surface.zig").Surface;

var recursion_depth_count: u64 = 0;
var recursion_depth_count_prev: u64 = 0;
var reflection_count: u64 = 0;
var reflection_count_prev: u64 = 0;

inline fn background_color(ray: Ray) Color {
    const unit_direction = ray.direction.unit_vector();
    const t = 0.5 * (unit_direction.y() + 1.0);
    return Color.white.scale(1.0-t)
            .add(Color.init(0.5, 0.7, 1.0).scale(t));
}

fn ray_color(ray: Ray, surfaces: ArrayList(Surface), depth: u32) Color {
    if (depth <= 0) {
        recursion_depth_count += 1;
        return Color.black;
    }
    var t_min: BaseFloat = 0.001;
    var t_max = math.inf(BaseFloat);
    var closest_hit: ?HitRecord = null;
    for (surfaces.items) |*surface, index| {
        const current_hit_record = surface.hit(ray, t_min, t_max);
        if (current_hit_record != null) {
            closest_hit = current_hit_record.?;
            t_max = closest_hit.?.t;
        }
    }
    if (closest_hit == null) {
        return background_color(ray);
    }
    const hit_record = closest_hit.?;
    const hit_surface = hit_record.surface;
    const material = hit_surface.material();
    const potential_scattering = material.scatter(ray, hit_record);
    if (potential_scattering == null) {
        // material fully absorbed the ray
        return Color.black;
    }
    reflection_count += 1;
    const scattering = potential_scattering.?;
    // material reflected the ray
    return scattering.attenuation.multiply(ray_color(scattering.scattered_ray, surfaces, depth - 1));
}

fn print_progress(scanline: u64, total_scanlines: u64, pixels_processed: u64) void {
    std.debug.warn("Scanline: {}/{} Pixels: {} Recursion limit: {} Reflections: {}\n",
                   .{scanline, total_scanlines, pixels_processed,
                   (recursion_depth_count - recursion_depth_count_prev),
                   (reflection_count - reflection_count_prev)});
    recursion_depth_count_prev = recursion_depth_count;
    reflection_count_prev = reflection_count;
}

// TODO print progress
pub fn render(allocator: *Allocator, random: *Random,
                camera: Camera, surfaces: ArrayList(Surface),
                width: u16, height: u16,
                samples_per_pixel: u16, max_depth: u16) ! *Image {
    std.debug.warn("Raytrace start\n", .{});
    std.debug.warn(" - Surfaces: {}\n", .{surfaces.items.len});
    std.debug.warn(" - Pixels: {}x{}\n", .{width, height});
    std.debug.warn(" - Samples per pixel: {}\n", .{samples_per_pixel});
    std.debug.warn(" - Recursion depth: {}\n", .{max_depth});
    var image = try Image.init(allocator, width, height);

    var pixels_processed: u64 = 0;
    const f_width = @intToFloat(BaseFloat, width);
    const f_height = @intToFloat(BaseFloat, height);

    var color_acc = Color.new_black();
    const color_scale = 1.0 / @intToFloat(f32, samples_per_pixel);

    var y: usize = 0;
    while (y < image.height) : (y += 1) {
        const f_y = @intToFloat(BaseFloat, y);

        var x: usize = 0;
        while (x < image.height) : (x += 1) {
            color_acc.set_mutate(Color.new_black());
            pixels_processed += 1;
            // TODO implement
            var sample: usize = 0;
            while (sample < samples_per_pixel) : (sample += 1) {
                const u = (@intToFloat(BaseFloat, x) + random.float(BaseFloat) - 0.5) / f_width;
                const v = (f_y + random.float(BaseFloat) - 0.5) / f_height;
                const ray = camera.get_ray(u, v);
                const color = ray_color(ray, surfaces, max_depth);
                color_acc.add_mutate(color);
            }
            const image_offset = y * width + x;
            image.pixels[image_offset] = color_acc.scale(color_scale);
        }
        print_progress(@as(u64, y + 1), height, pixels_processed);
    }
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

    const black_metal = Material.init_metal(Metal.init(Color.black));
    const gold_metal = Material.init_metal(Metal.init(Color.gold));
    const red_metal = Material.init_metal(Metal.init(Color.red));
    const green_metal = Material.init_metal(Metal.init(Color.green));
    const blue_metal = Material.init_metal(Metal.init(Color.blue));
    const white_metal = Material.init_metal(Metal.init(Color.white));


    const silver_metal = Material.init_lambertian(Lambertian.init(random, Color.silver));

    const green_matte = Material.init_lambertian(Lambertian.init(random, Color.green));
    const purple_matte = Material.init_lambertian(Lambertian.init(random, Color.init(0.5, 0., 0.5)));

    // TODO this copies the materials with objects
    try objects.append(Surface.init_sphere(Sphere.init(Vec3.z_unit.scale(6), 2.0, gold_metal)));
    try objects.append(Surface.init_sphere(Sphere.init(Vec3.init(3., 1, 4.0), 1.0, purple_matte)));
    try objects.append(Surface.init_sphere(Sphere.init(Vec3.init(1., 102.5, 4.0), 100.0, green_matte)));

    const width = 400;
    const height = 400;
    const samples_per_pixel = 1000;
    const max_depth = 30;
    const scene_image = try render(allocator, random, camera, objects,
                                width, height, samples_per_pixel, max_depth);
    defer scene_image.deinit();
    const foo = ppm_image.write_file("./target/render_test.ppm", scene_image);
}
