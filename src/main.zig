const std = @import("std");
const Raytrace = @import("raytrace.zig");


pub fn main() ! void {
    var args = std.process.args();
    std.debug.warn("raytrace\n", .{});
    std.debug.warn("USAGE;\n", .{});
    std.debug.warn("raytrace width heigth samples depth filename\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = &arena.allocator;
    // _ = args.skip();

    const width = args.next(alloc);
    const height = args.next(alloc);

    std.debug.warn("w={} h={}\n", .{width, height});


}
