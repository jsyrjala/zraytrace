const std = @import("std");
const raytrace = @import("raytrace.zig");
const RenderParams = raytrace.RenderParams;
const scenes = @import("scenes.zig");
const png_image = @import("png_image.zig");

fn parse_int_arg(alloc: *std.mem.Allocator, args: *std.process.ArgIterator) ! u16 {
    const s = try args.next(alloc).?;
    return try std.fmt.parseInt(u16, s, 10);
}

pub fn main() ! void {
    var args = std.process.args();
    std.debug.warn("raytrace\n", .{});
    std.debug.warn("USAGE;\n", .{});
    std.debug.warn("raytrace width heigth samples depth scene_index filename\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = &arena.allocator;
    _ = args.skip();

    const width = try parse_int_arg(alloc, &args);
    const height = try parse_int_arg(alloc, &args);
    const samples = try parse_int_arg(alloc, &args);
    const max_depth = try parse_int_arg(alloc, &args);
    const scene_index: u16 = try parse_int_arg(alloc, &args);

    const filename = try args.next(alloc).?;

    const render_params = RenderParams{.width = width, .height = height,
                                        .samples_per_pixel = samples, .max_depth = max_depth,
                                        .bounded_volume_hierarchy = true};
    const scene_image = try scenes.render_scene(alloc, render_params, scene_index);
    defer scene_image.deinit();
    _ = try png_image.writeFile(alloc, filename, scene_image);
}
