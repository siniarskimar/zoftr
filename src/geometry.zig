const std = @import("std");
const linmath = @import("linmath.zig");

pub fn Rect(P: type) type {
    _ = linmath.typeInfoVec(P);
    return struct { P, P };
}

pub fn findBoundingBox(P: type, points: []const P) Rect(P) {
    std.debug.assert(points.len != 0);

    var min: P = points[0];
    var max: P = points[0];

    for (points) |p| {
        for (p, &min) |candidate, *min_comp| {
            min_comp.* = @min(min_comp.*, candidate);
        }
        for (p, &max) |candidate, *max_comp| {
            max_comp.* = @max(max_comp.*, candidate);
        }
    }

    return .{ min, max };
}
