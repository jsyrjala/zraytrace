const std = @import("std");
const vectors = @import("vectors.zig");
// const Vec3 = vectors.Vec3;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Vec3 = struct {
    const Self = @This();
    x: f32,
    y: f32,
    z: f32,

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{.x = x, .y = y, .z = z};
    }
};

pub fn create_vectors(allocator: *Allocator) anyerror!*ArrayList(Vec3) {
    std.debug.warn("create_vectors.\n", .{});
    std.debug.warn("after init.\n", .{});

    var list = ArrayList(Vec3).init(allocator);
    std.debug.warn("after init 1.\n", .{});

    //const vec = Vec3.new(1.0, 2.0, @intToFloat(f32, 42));
    const v = Vec3{.x = 1., .y = 2., .z = 3.};
    std.debug.warn("after init 2.\n", .{});

    try list.append(v);
    std.debug.warn("after init 3.\n", .{});

    var heap_list = try allocator.create(ArrayList(Vec3));
    std.debug.warn("after init 4.\n", .{});
    heap_list.* = list;
    return heap_list;
}

pub fn create_vectors_3(allocator: *Allocator) anyerror ! *[]Vec3 {
    var vecs = try allocator.alloc(Vec3, 10);
    for (vecs) |*vec, i| {
        std.mem.copy(Vec3, vec, Vec3.init(1.0,@intToFloat(f32, i),@intToFloat(f32, i)));
    }
    return vecs;
}



pub fn create_vectors_2(allocator: *Allocator) anyerror ! *[10]Vec3 {
    var vecs: [10]Vec3 = undefined;
    for (vecs) |*vec, i| {
        vec.* = Vec3.init(@intToFloat(f32, i),@intToFloat(f32, i),@intToFloat(f32, i));
    }
    return &vecs;
}

pub fn alloc_mem(allocator: *Allocator) anyerror ! []u8 {
    std.debug.warn("alloc mem.\n", .{});
    const data = try allocator.alloc(u8, 10);
    std.debug.warn("alloc after alloc.\n", .{});

    return data;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    // why const is not allowed here?
    const rand = std.rand;
    const DefaultPrng = rand.DefaultPrng;
    const rng = DefaultPrng.init(0);
    var random = rng.random;
    const value = random.int(i64);
    std.debug.warn("value {}.\n", .{value});



    const vec_list = try alloc_mem(allocator);
    std.debug.warn("create_vectors return.\n", .{});
    // defer vec_list.deinit();
    std.debug.warn("create_vectors end.\n", .{});
    //for (vecs2) |*vec, i| {
    //    std.debug.warn("value2 {}.\n", .{vec.*});
    //}

    //for (vec_list.items) |*vec, i| {
    //    std.debug.warn("c={} i={}.\n", .{vec.*, i});
    //}
    // std.debug.warn("value1 {}.\n", .{@TypeOf(std.ArrayList.init(allocator))  });
}
