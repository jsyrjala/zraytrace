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
const Sphere = @import("sphere.zig").Sphere;
const Camera = @import("camera.zig").Camera;

inline fn background_color(ray: Ray) Color {
    const unit_direction = ray.direction.unit_vector();
    const t = 0.5*(unit_direction.y() + 1.0);
    return Color.white.scale(1.0-t)
            .add(Color.init(0.5, 0.7, 1.0).scale(t));
}

inline fn ray_color(ray: Ray, objects: ArrayList(Sphere), depth: u32) Color {
    if (depth <= 0) {
        return Color.black;
    }
    var t_min: BaseFloat = 0.001;
    var t_max = math.inf(BaseFloat);
    var closest_hit: ?HitRecord = null;
    for (objects.items) |*sphere, index| {
        const hit_record = sphere.hit(ray, t_min, t_max);
        if (hit_record != null) {
            closest_hit = hit_record.?;
            t_max = closest_hit.?.t;
        }
    }
    if (closest_hit == null) {
        return background_color(ray);
    }
    // hitting sphere
    // some random color based on hit location
    const n = closest_hit.?.normal.unit_vector();
    return Color.init(n.x() * 0.5 + 1.0, n.y() * 0.5 + 1.0, n.z() * 0.5 + 1.0);
}

fn print_progress(scanline: u64, total_scanlines: u64, pixels_processed: u64) void {
    std.debug.warn("Scanline: {}/{} Pixels: {}\n",
                   .{scanline, total_scanlines, pixels_processed});
}

// TODO print progress
pub fn render(allocator: *Allocator, random: *Random,
                camera: Camera, objects: ArrayList(Sphere),
                width: u16, height: u16,
                samples_per_pixel: u16, max_depth: u16) ! *Image {
    std.debug.warn("Raytrace start\n", .{});
    // std.debug.warn(" - Objects: ", .{size(world.objects)[1])
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
                const color = ray_color(ray, objects, max_depth);
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

test "Render something" {
    const camera = Camera.init(Vec3.origin, Vec3.z_unit, Vec3.y_unit, 45.0, 1.0);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var objects = ArrayList(Sphere).init(allocator);
    defer objects.deinit();
    var prng = std.rand.DefaultPrng.init(42);
    var random = &prng.random;

    try objects.append(Sphere.init(Vec3.z_unit.scale(6), 2.0));
    try objects.append(Sphere.init(Vec3.init(1., 0.5, 4.0), 1.0));
    try objects.append(Sphere.init(Vec3.init(1., 102.5, 4.0), 100.0));

    const width = 100;
    const height = 100;
    const samples_per_pixel = 10;
    const max_depth = 10;
    const scene_image = try render(allocator, random, camera, objects,
                                width, height, samples_per_pixel, max_depth);
    defer scene_image.deinit();
    const foo = ppm_image.write_file("./target/render_test.ppm", scene_image);
}
