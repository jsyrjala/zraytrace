//! Reader for Wavefront OBJ file format
//! https://en.wikipedia.org/wiki/Wavefront_.obj_file
//! https://www.fileformat.info/format/wavefrontobj/egff.htm

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Vec3 = @import("vector.zig").Vec3;
const Material = @import("material.zig").Material;
const Surface = @import("surface.zig").Surface;
const Triangle = @import("triangle.zig").Triangle;
const AABB = @import("aabb.zig").AABB;

const FaceVertex = struct {
    vertex: u64,
    texture: ?u64,
    vertex_normal: ?u64,
};

/// Parse face vertex to components: vertex, texture coordinate, vertex normal
fn parseFaceVertex(line: []const u8) ! FaceVertex {
    // 1 2 3 4 => vertex indexes
    // 1/1 2/2 3/3 => vertex index/texture coordinate index
    // 1/1/1 2/2/2 3/3/3 => vertex index/texture coordinate index/vertex normal index
    // 1//1 2//2 3//3 => vertex index//vertex normal index
    // faces refer to vertex indexes
    var splitter = std.mem.tokenize(u8, line, "/");
    
    const v: u64 = try std.fmt.parseInt(u64, splitter.next() orelse "", 10);
    const texture_index = splitter.next();
    if (texture_index == null or texture_index.?.len == 0) {
        return FaceVertex{.vertex = v, .texture = null, .vertex_normal = null};
    }
    const t: u64 = try std.fmt.parseInt(u64, texture_index.?, 10);

    const vertex_normal_index = splitter.next();
    if (vertex_normal_index == null) {
        return FaceVertex{.vertex = v, .texture = t, .vertex_normal = null};
    }

    const vn: u64 = try std.fmt.parseInt(u64, vertex_normal_index.?, 10);
    return FaceVertex{.vertex = v, .texture = t, .vertex_normal = vn};
}

const ParseError = error {
    WrongNumberOfFaceVertexes,
};

/// Create triangle
fn createTri(vertexes: *ArrayList(Vec3), material: *const Material,
             a_index: FaceVertex, b_index: FaceVertex, c_index: FaceVertex) Triangle {
    // indices in OJB file are 1-based
    // vertexes uses 0-based index
    return Triangle.init(
        vertexes.items[a_index.vertex - 1],
        vertexes.items[b_index.vertex - 1],
        vertexes.items[c_index.vertex - 1],
        material
    );
}

/// Parse triangles from a set of FaceVertexes.
/// One face in OBJ may be parsed as several triangles.
fn parseTriangles(allocator: *Allocator, material: *const Material,
                vertexes: *ArrayList(Vec3), face_vertexes: *ArrayList(FaceVertex)) ! ArrayList(Triangle) {
    // Convert faces to triangles
    // Most of the faces have 4 vertexes, some have 3 and few have 5
    // 3 vertexes: 0,1,2
    // 4 vertexes: 0,1,2  2,3,0
    //  1 4
    //  2 3
    // 5 vertexes: 0,1,2  2,3,0  3,4,0
    //   1
    // 2   5
    //  3 4
    // 6 vertexes: 0,1,2  2,3,0  3,4,0  4,5,0
    //  1 6
    // 2   5
    //  3 4
    if (face_vertexes.items.len < 3) {
        return ParseError.WrongNumberOfFaceVertexes;
    }
    var triangles = ArrayList(Triangle).init(allocator);
    // the first triangle is always the same
    const items = face_vertexes.items;
    try triangles.append(createTri(vertexes, material, items[0], items[1], items[2]));

    switch(items.len) {
        3 => {
            return triangles;
        },
        4 => {
            try triangles.append(createTri(vertexes, material, items[2], items[3], items[0]));
            return triangles;
        },
        5 => {
            try triangles.append(createTri(vertexes, material, items[2], items[3], items[0]));
            try triangles.append(createTri(vertexes, material, items[3], items[4], items[0]));
            return triangles;
        },
        6 => {
            try triangles.append(createTri(vertexes, material, items[2], items[3], items[0]));
            try triangles.append(createTri(vertexes, material, items[3], items[4], items[0]));
            try triangles.append(createTri(vertexes, material, items[4], items[5], items[0]));
            return triangles;
        },
        else => {
            return ParseError.WrongNumberOfFaceVertexes;
        }
    }
}

/// ReadObj file to a List of surfaces
pub fn readObjFile(allocator: *Allocator, filename: []const u8, material: *const Material) !ArrayList(Surface) {
    std.debug.warn("Reading OBJ model from {s}\n", .{filename});
    // this the return value from the function, not freeing it here
    var surfaces = ArrayList(Surface).init(allocator);

    const file = try std.fs.cwd().openFile(filename, .{.read = true});
    defer file.close();
    const input = file.reader();

    // TODO vertexes, faces, normals should be freed,
    // final surface list should not be freed
    // TODO check file existance
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const tmp_allocator = &arena.allocator;

    var vertexes = ArrayList(Vec3).init(tmp_allocator);
    defer vertexes.deinit();

    var vertex_normals = ArrayList(Vec3).init(tmp_allocator);
    defer vertex_normals.deinit();

    var face_count:u32 = 0;
    while (true) {
        var line = input.readUntilDelimiterAlloc(tmp_allocator, '\n', 20000) catch |err| {
            switch (err) {
                error.EndOfStream => break,
                else => return err
            }
        };
        if (line.len < 1) {
            continue;
        } 
        if (line[line.len - 1] == 0x0d) {
            // remove possible carriage return
            line = line[0..line.len - 1];
        }
        if (line[0] == 'v' and line[1] == ' ') {
            var splitter = std.mem.tokenize(u8, line, " ");
            // eat "v" from the start
            _ = splitter.next();
            const x:f32 = try std.fmt.parseFloat(f32, splitter.next() orelse "");
            const y:f32 = try std.fmt.parseFloat(f32, splitter.next() orelse "");
            const z:f32 = try std.fmt.parseFloat(f32, splitter.next() orelse "");
            const vec = Vec3.init(x,y,z);
            try vertexes.append(vec);
        } else if (line[0] == 'f' and line[1] == ' ') {
            var splitter = std.mem.tokenize(u8, line, " ");
            // eat "f" from the start
            _ = splitter.next();
            var face_vertexes = ArrayList(FaceVertex).init(tmp_allocator);
            defer face_vertexes.deinit();
            while (splitter.next()) |s| {
                const face = try parseFaceVertex(s);
                try face_vertexes.append(face);
            }

            const triangles = try parseTriangles(tmp_allocator, material, &vertexes, &face_vertexes);
            for (triangles.items) |triangle| {
                try surfaces.append(Surface.initTriangle(triangle));
            }
            face_count += 1;
        } else if (line[0] == 'v' and line[1] == 'n' and line[2] == ' ') {
            var splitter = std.mem.tokenize(u8, line, " ");
            // eat "vn" from the start
            _ = splitter.next();
            const x:f32 = try std.fmt.parseFloat(f32, splitter.next() orelse "");
            const y:f32 = try std.fmt.parseFloat(f32, splitter.next() orelse "");
            const z:f32 = try std.fmt.parseFloat(f32, splitter.next() orelse "");
            const vec = Vec3.init(x,y,z);
            try vertex_normals.append(vec);
        } else {

        }
    }
    std.debug.warn("Found\n", .{});
    std.debug.warn("  center point:   {}\n", .{Vec3.center(vertexes)});
    std.debug.warn("  bounding box:   {}\n", .{AABB.initVertexes(vertexes.items)});
    std.debug.warn("  vertexes:       {}\n", .{vertexes.items.len});
    std.debug.warn("  vertex normals: {}\n", .{vertex_normals.items.len});
    std.debug.warn("  faces:          {}\n", .{face_count});
    std.debug.warn("  triangles:      {}\n", .{surfaces.items.len});
    std.debug.warn("  surfaces:       {}\n", .{surfaces.items.len});
    return surfaces;
}

//// Testing
test "read_obj_file Man.obj" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const filename = "./models/man/Man.obj";
    _ = try readObjFile(allocator, filename, &Material.silver_metal);
}

test "read_obj_file bunny.obj" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const filename = "./models/bunny/bunny.obj";
    _ = try readObjFile(allocator, filename, &Material.silver_metal);
}

test "read_obj_file teapot.obj" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const filename = "./models/teapot/teapot.obj";
    _ = try readObjFile(allocator, filename, &Material.silver_metal);
}
