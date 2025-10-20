// ZCoreMath: cast.zig
// Explicit, safe, deterministic casts between integers and floats.

const std = @import("std");
const traits = @import("traits.zig");
pub const Real = traits.Real;

pub const CastError = error{
    Overflow,
    NaNInput,
};

/// Saturating integer cast: clamps into destination range.
pub fn toIntSaturate(comptime Dst: type, x: anytype) Dst {
    const dst_info = @typeInfo(Dst);
    if (dst_info != .int) @compileError("toIntSaturate: Dst must be an integer type");

    const dst_min: Dst = std.math.minInt(Dst);
    const dst_max: Dst = std.math.maxInt(Dst);

    return switch (@typeInfo(@TypeOf(x))) {
        // runtime ints
        .int => blk: {
            const xi = @as(i128, @intCast(x));
            const lo = @as(i128, @intCast(dst_min));
            const hi = @as(i128, @intCast(dst_max));
            if (xi <= lo) break :blk dst_min;
            if (xi >= hi) break :blk dst_max;
            break :blk @as(Dst, @intCast(x));
        },
        // comptime ints (e.g. 123, 1_000_000)
        .comptime_int => blk: {
            const xi = @as(i128, x);
            const lo = @as(i128, @intCast(dst_min));
            const hi = @as(i128, @intCast(dst_max));
            if (xi <= lo) break :blk dst_min;
            if (xi >= hi) break :blk dst_max;
            break :blk @as(Dst, @intCast(xi));
        },
        // runtime floats
        .float => blk: {
            const xf = @as(Real, x);
            if (!std.math.isFinite(xf)) break :blk (if (xf < 0) dst_min else dst_max);

            const lo_f = @as(Real, @floatFromInt(dst_min));
            const hi_f = @as(Real, @floatFromInt(dst_max));
            if (xf <= lo_f) break :blk dst_min;
            if (xf >= hi_f) break :blk dst_max;

            break :blk @as(Dst, @intFromFloat(xf));
        },
        // comptime floats (e.g. 123.0, -9e9)
        .comptime_float => blk: {
            const xf = @as(Real, x);
            if (!std.math.isFinite(xf)) break :blk (if (xf < 0) dst_min else dst_max);

            const lo_f = @as(Real, @floatFromInt(dst_min));
            const hi_f = @as(Real, @floatFromInt(dst_max));
            if (xf <= lo_f) break :blk dst_min;
            if (xf >= hi_f) break :blk dst_max;

            break :blk @as(Dst, @intFromFloat(xf));
        },
        else => @compileError("toIntSaturate: unsupported source type"),
    };
}

/// Checked integer cast: returns error on overflow or non-finite float.
pub fn toIntChecked(comptime Dst: type, x: anytype) CastError!Dst {
    const dst_info = @typeInfo(Dst);
    if (dst_info != .int) @compileError("toIntChecked: Dst must be an integer type");

    const dst_min: Dst = std.math.minInt(Dst);
    const dst_max: Dst = std.math.maxInt(Dst);

    return switch (@typeInfo(@TypeOf(x))) {
        .int => blk: {
            const xi = @as(i128, @intCast(x));
            const lo = @as(i128, @intCast(dst_min));
            const hi = @as(i128, @intCast(dst_max));
            if (xi < lo or xi > hi) break :blk CastError.Overflow;
            break :blk @as(Dst, @intCast(x));
        },
        .comptime_int => blk: {
            const xi = @as(i128, x);
            const lo = @as(i128, @intCast(dst_min));
            const hi = @as(i128, @intCast(dst_max));
            if (xi < lo or xi > hi) break :blk CastError.Overflow;
            break :blk @as(Dst, @intCast(xi));
        },
        .float => blk: {
            const xf = @as(Real, x);
            if (!std.math.isFinite(xf)) break :blk CastError.NaNInput;

            const lo_f = @as(Real, @floatFromInt(dst_min));
            const hi_f = @as(Real, @floatFromInt(dst_max));
            if (xf < lo_f or xf > hi_f) break :blk CastError.Overflow;

            break :blk @as(Dst, @intFromFloat(xf));
        },
        .comptime_float => blk: {
            const xf = @as(Real, x);
            if (!std.math.isFinite(xf)) break :blk CastError.NaNInput;

            const lo_f = @as(Real, @floatFromInt(dst_min));
            const hi_f = @as(Real, @floatFromInt(dst_max));
            if (xf < lo_f or xf > hi_f) break :blk CastError.Overflow;

            break :blk @as(Dst, @intFromFloat(xf));
        },
        else => @compileError("toIntChecked: unsupported source type"),
    };
}

/// Checked float cast: integer/float to `Real` with NaN/Inf checks.
pub fn toFloatChecked(x: anytype) CastError!Real {
    return switch (@typeInfo(@TypeOf(x))) {
        .int => @as(Real, @floatFromInt(x)),
        .comptime_int => @as(Real, @floatFromInt(x)),
        .float => {
            if (!std.math.isFinite(x)) return CastError.NaNInput;
            return @as(Real, x);
        },
        .comptime_float => {
            if (!std.math.isFinite(@as(Real, x))) return CastError.NaNInput;
            return @as(Real, x);
        },
        else => @compileError("toFloatChecked: unsupported source type"),
    };
}

test "toIntSaturate from float clamps" {
    const hi: i8 = toIntSaturate(i8, 1e9);
    try std.testing.expect(hi == std.math.maxInt(i8));
    const lo: i8 = toIntSaturate(i8, -1e9);
    try std.testing.expect(lo == std.math.minInt(i8));
}

test "toIntChecked happy path" {
    const v = try toIntChecked(i16, 1234);
    try std.testing.expect(v == 1234);
}

test "toIntChecked overflow" {
    const e = toIntChecked(i8, 200);
    try std.testing.expectError(CastError.Overflow, e);
}

test "toFloatChecked from int/float" {
    const a = try toFloatChecked(42);
    try std.testing.expect(a == 42);
    const b = try toFloatChecked(@as(Real, 3.25));
    try std.testing.expect(b == 3.25);
}
