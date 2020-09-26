const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn alloc_mem(allocator: *Allocator) ! []u8 {
    std.debug.warn("alloc mem.\n", .{});
    const data = try allocator.alloc(u8, 10);
    std.debug.warn("alloc after alloc.\n", .{});
    data[2] = 42;
    return data;
}

pub fn array_list_u8(allocator: *Allocator) ! ArrayList(u8) {
    var list: ArrayList(u8) = ArrayList(u8).init(allocator);
    try list.append(42);
    try list.append(255);
    return list;
}


const Vec2 = struct {
    x: f32,
    y: f32,
    pub fn new(x: f32, y: f32) Vec2 {
        return Vec2{.x = x, .y= y};
    }
    pub inline fn copy(allocator: *Allocator, v:Vec2) !*Vec2 {
        const new_vec2: *Vec2 = try allocator.create(Vec2);
        new_vec2.* = v;
        return new_vec2;
    }
};

pub fn array_list_struct(allocator: *Allocator) ! ArrayList(Vec2) {
    var list = ArrayList(Vec2).init(allocator);
    try list.append(Vec2.new(1., 2.));
    try list.append(Vec2.new(3., 7.));
    const c_copy = try Vec2.copy(allocator, Vec2.new(3., 7.));
    try list.append(c_copy.*);
    return list;
}


pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    // memory alloc
    std.debug.warn("Memory alloc.\n", .{});
    const data = try alloc_mem(allocator);
    defer allocator.free(data);

    for (data) | *c, index | {
        std.debug.warn("i={} c={}.\n", .{index, c.*});
    }

    // arraylist of bytes
    std.debug.warn("ArrayList of bytes.\n", .{});
    const byte_list = try array_list_u8(allocator);
    defer byte_list.deinit();

    for (byte_list.items) | *c, index | {
        std.debug.warn("i={} c={}.\n", .{index, c.*});
    }

    // arraylist of structs
    std.debug.warn("ArrayList of structs.\n", .{});
    const struct_list = try array_list_struct(allocator);
    defer struct_list.deinit();

    for (struct_list.items) | *c, index | {
        std.debug.warn("i={} c={}.\n", .{index, c.*});
    }

    // random values
    const fixed_seed = 0xcafe;
    std.debug.warn("Random values with fixed seed. {}\n", .{fixed_seed});
    var random1 = std.rand.DefaultPrng.init(fixed_seed).random;
    std.debug.warn("random int {}\n", .{random1.int(u16)});
    std.debug.warn("random int {}\n", .{random1.int(u16)});
    std.debug.warn("random int {}\n", .{random1.int(u16)});
    std.debug.warn("random float {}\n", .{random1.float(f32)});

    var timestamp_seed = std.time.milliTimestamp();
    //timestamp_seed += 1;
    //std.debug.warn("Random values with timestamp seed. {}\n", .{timestamp_seed});
    var random2 = std.rand.DefaultPrng.init(timestamp_seed).random;
    std.debug.warn("random int {}\n", .{random2.int(u16)});
    std.debug.warn("random int {}\n", .{random2.int(u16)});
    std.debug.warn("random int {}\n", .{random2.int(u16)});
    std.debug.warn("random float {}\n", .{random2.float(f32)});

}
