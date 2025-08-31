const std = @import("std");

/// Verify that `T` is a scalar type (int, float or bool)
pub fn Scalar(T: type) type {
    const typeinfo = @typeInfo(T);
    switch (typeinfo) {
        .int, .float, .bool => {},
        else => @compileError(@typeName(T) ++ " is not a scalar type"),
    }

    return T;
}

/// Reflect on vector type.
/// Vector is an array `[N]child` or `@Vector(N, child)`
pub fn typeInfoVec(T: type) struct {
    child: type,
    N: comptime_int,
    is_simd: bool = false,
} {
    return switch (@typeInfo(T)) {
        .array => |array| .{ .child = Scalar(array.child), .N = array.len },
        .vector => |vector| .{ .child = vector.child, .N = vector.len, .is_simd = true },
        else => @compileError("expected T to be an array type, got '" ++ @typeName(T) ++ "'"),
    };
}

/// Reflect on matrix type.
/// A matrix is an array `[M][N]child` or `[M]@Vector(N, child)`
pub fn typeInfoMat(T: type) struct {
    child: type,
    N: comptime_int,
    M: comptime_int,
    is_simd: bool,
} {
    const typeinfo = @typeInfo(T);

    if (typeinfo != .array)
        @compileError("expected T to be a 2D array type, got '" ++ @typeName(T) ++ "'");

    const matrix_info = typeinfo.array;
    const row_info = typeInfoVec(matrix_info.child);

    return .{
        .child = row_info.child,
        .N = row_info.N,
        .M = matrix_info.len,
        .is_simd = row_info.is_simd,
    };
}

/// Compute dot product of vectors.
/// Adapts to whether a vector is @Vector or an array based on type.
pub fn vecDot(a: anytype, b: @TypeOf(a)) typeInfoVec(@TypeOf(a)).child {
    const vec_typeinfo = typeInfoVec(@TypeOf(a));
    if (vec_typeinfo.is_simd) {
        return @reduce(.Add, a * b);
    }

    var result: vec_typeinfo.child = 0;
    inline for (0..vec_typeinfo.N) |idx| {
        result += a[idx] * b[idx];
    }

    return result;
}

/// Compute a cross product of vectors.
/// Does not allow @Vector due to amount of swizzling required.
pub fn vec3Cross(S: type, a: [3]S, b: [3]S) [3]Scalar(S) {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

/// Get vector magnitude (length) squared.
pub fn vecMagSquared(a: anytype) typeInfoVec(@TypeOf(a)).child {
    return vecDot(a, a);
}

/// Get unit vector from vector `a`
pub fn vecUnit(a: anytype) @TypeOf(a) {
    const typeinfo = typeInfoVec(@TypeOf(a));
    const V = @Vector(typeinfo.N, typeinfo.child);
    const v: V = a;
    return v / @as(V, @splat(@sqrt(vecMagSquared(a))));
}

/// Get a unit vector from angle in radians
/// Angle of `0` points at `{0, 1}`
pub fn vec2Dir(T: type, rad: f32) [2]T {
    return .{ @sin(rad), @cos(rad) };
}

/// Intended to be used in tests. Copy-paste of
/// `std.testing.print`, which is not public.
pub fn testPrint(comptime fmt: []const u8, args: anytype) void {
    if (@inComptime()) {
        @compileError(std.fmt.comptimePrint(fmt, args));
    } else if (std.testing.backend_can_print) {
        std.debug.print(fmt, args);
    }
}

/// Intended to be used in tests. Tests whether the
/// elements are approximately equal by `eps`
pub fn expectSlicesApproxEqual(
    T: type,
    comptime mode: enum { abs, rel },
    expected: []const T,
    actual: []const T,
    eps: T,
) !void {
    if (expected.len != actual.len) {
        testPrint("slices not equal - slices differ in length\n", .{});
        return error.TestExpectedEqual;
    }
    var diff_idx: usize = 0;

    while (diff_idx < expected.len) : (diff_idx += 1) {
        const eq = if (mode == .abs)
            std.math.approxEqAbs(T, expected[diff_idx], actual[diff_idx], eps)
        else
            std.math.approxEqRel(T, expected[diff_idx], actual[diff_idx], eps);

        if (!eq) break;
    }

    if (diff_idx == expected.len) return;

    testPrint(
        \\slices not equal - first difference at index {}
        \\   expected: {}
        \\   actual: {}
        \\   tolerance: {}
        \\
    , .{ diff_idx, expected[diff_idx], actual[diff_idx], eps });

    return error.TestExpectedEqual;
}

test vec2Dir {
    // Casting a wide net since precision depends on the environment the test is in
    const tolerance = 0.000001;

    try expectSlicesApproxEqual(f64, .abs, &.{ 0, 1 }, &vec2Dir(f64, 0), tolerance);
    try expectSlicesApproxEqual(f64, .abs, &.{ 0, 1 }, &vec2Dir(f64, std.math.pi * 2.0), tolerance);
    try expectSlicesApproxEqual(f64, .abs, &.{ 1, 0 }, &vec2Dir(f64, std.math.pi / 2.0), tolerance);
    try expectSlicesApproxEqual(f64, .abs, &.{ 0, -1 }, &vec2Dir(f64, std.math.pi), tolerance);
    try expectSlicesApproxEqual(f64, .abs, &.{ -1, 0 }, &vec2Dir(f64, (std.math.pi / 2.0) * 3), tolerance);

    // 45 deg
    try expectSlicesApproxEqual(
        f64,
        .abs,
        &.{ 0.707106781187, 0.707106781187 },
        &vec2Dir(f64, (std.math.pi / 4.0)),
        tolerance,
    );
}

test vecDot {
    const tolerance = std.math.floatEps(f32);
    try std.testing.expectApproxEqAbs(
        1,
        vecDot([2]f32{ 1, 0 }, [2]f32{ 1, 0 }),
        tolerance,
    );
    try std.testing.expectApproxEqAbs(
        0,
        vecDot([2]f32{ 0, 1 }, [2]f32{ 1, 0 }),
        tolerance,
    );
    try std.testing.expectApproxEqAbs(
        -1,
        vecDot([2]f32{ -1, 0 }, [2]f32{ 1, 0 }),
        tolerance,
    );

    try std.testing.expectApproxEqAbs(
        0.707106781187,
        vecDot([2]f32{ 1, 0 }, [2]f32{ 0.707106781187, 0.707106781187 }),
        tolerance,
    );

    // Test SIMD
    try std.testing.expectApproxEqAbs(
        0.707106781187,
        vecDot(@Vector(2, f32){ 1, 0 }, @Vector(2, f32){ 0.707106781187, 0.707106781187 }),
        tolerance,
    );
}
