/// ZCoreMath: traits.zig
/// Canonical scalar types and small helpers shared across the library.
const std = @import("std");

/// Public scalar used by kernels. Switch to `f32` if you want single-precision builds.
pub const Real: type = f64;

/// Public index type for ranges/loops (used by range.zig and tests).
pub const Index: type = usize;

/// Float predicate without relying on @typeInfo tags (robust across snapshots).
pub inline fn isFloatType(comptime T: type) bool {
    return switch (T) {
        f16, f32, f64, f128, comptime_float => true,
        else => false,
    };
}

/// Integer predicate without relying on @typeInfo tags.
pub inline fn isIntType(comptime T: type) bool {
    return switch (T) {
        comptime_int, isize, usize, i8, i16, i32, i64, i128, u1, u8, u16, u32, u64, u128 => true,
        else => false,
    };
}

/// IEEE-754 machine epsilon for a floating type `T`.
pub inline fn epsilon(comptime T: type) T {
    if (!isFloatType(T)) @compileError("epsilon: T must be a float type");
    return switch (T) {
        f16 => @as(T, 0x1p-10), // 2^(-10) where p=11
        f32 => @as(T, 0x1p-23), // 2^(-23) where p=24
        f64 => @as(T, 0x1p-52), // 2^(-52) where p=53
        f128 => @as(T, 0x1p-112), // 2^(-112) where p=113
        comptime_float => @as(T, 0x1p-52), // sane default for comptime floats
        else => @compileError("epsilon: unsupported float type"),
    };
}

/// Finite predicate:
/// - floats: std.math.isFinite
/// - integers: always true
pub inline fn isFinite(x: anytype) bool {
    const T = @TypeOf(x);
    if (isFloatType(T)) return std.math.isFinite(x);
    if (isIntType(T)) return true;
    @compileError("isFinite: unsupported type");
}

/// Sign helper returning -1, 0, or +1 (non-finite floats return 0).
pub inline fn sign(x: anytype) comptime_int {
    const T = @TypeOf(x);
    if (isIntType(T)) {
        return if (x < 0) -1 else if (x > 0) 1 else 0;
    } else if (isFloatType(T)) {
        if (!std.math.isFinite(x)) return 0;
        return if (x < 0) -1 else if (x > 0) 1 else 0;
    } else {
        @compileError("sign: unsupported type");
    }
}

test "traits: eps and isFinite" {
    const eps = epsilon(Real);
    try std.testing.expect(eps > 0);

    try std.testing.expect(isFinite(@as(Real, 1.0)));
    try std.testing.expect(!isFinite(std.math.inf(Real)));
    try std.testing.expect(!isFinite(-std.math.inf(Real)));

    // ints are always finite
    try std.testing.expect(isFinite(@as(usize, 42)));
}
