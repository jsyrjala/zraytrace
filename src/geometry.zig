//! A collection of surfaces.
//! Allows using scale/translate/rotate operation on every surface in the geometry.
const std = @import("std");
const ArrayList = std.ArrayList;
const Surface = @import("surface.zig").Surface;
const Vec3 = @import("surface.zig").Vec3;

pub const Geometry = struct {
    surfaces: *ArrayList(*Surface),
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) ! Geometry {
        var list = try allocator.create(ArrayList(*Surface));
        list.* = ArrayList(*Surface).init(allocator);
        return Geometry{.surfaces = list,
                        .allocator = allocator};
    }

    pub fn addSurface(self: Geometry, surface: *Surface) ! void {
        try self.surfaces.append(surface);
    }

    pub fn addAllSurfaces(self: Geometry, surfaces: ArrayList(*Surface)) ! void {
        for (surfaces.items) |surface| {
            try self.addSurface(surface);
        }
    }

    pub fn translate(self: Geometry, translation: Vec3) void {
        for (self.surfaces.items) |*surface| {
            surface.translate(translation);
        }
    }

    pub fn scale(self: Geometry, scale: Vec3) void {
        // loop over each coordinate and multiply it with coordinate from scale
        for (self.surfaces.items) |*surface| {
            surface.scale(scale);
        }
    }

    // TODO rotation matric
    pub fn rotate(self: Geometry, rotation: Vec3) void {
        // loop over each coordinate and multiply it with coordinate from scale
        for (self.surfaces.items) |*surface| {
            surface.rotate(rotation);
        }
    }
};

//// Testing
const Sphere = @import("sphere.zig").Sphere;
const expectEqual = std.testing.expectEqual;

test "Geometry.init()" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    const geometry = try Geometry.init(allocator);
    // var sphere = allocator.create(Surface);
    var sphere1 = Surface.initSphere(Sphere.unit_sphere);
    expectEqual(@as(usize, 0), geometry.surfaces.items.len);
    try geometry.addSurface(&sphere1);
    expectEqual(@as(usize, 1), geometry.surfaces.items.len);


    var list = ArrayList(*Surface).init(allocator);
    var sphere2 = Surface.initSphere(Sphere.unit_sphere);
    var sphere3 = Surface.initSphere(Sphere.unit_sphere);
    var sphere4 = Surface.initSphere(Sphere.unit_sphere);
    try list.append(&sphere2);
    try list.append(&sphere3);
    try list.append(&sphere4);

    try geometry.addAllSurfaces(list);

    expectEqual(@as(usize, 4), geometry.surfaces.items.len);
}
