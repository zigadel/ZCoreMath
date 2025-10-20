/// ZCoreMath: util.zig
/// Deterministic helpers for floating-point comparisons and small numeric utilities.
/// - No allocation, no syscalls. Pure and WASM-friendly.
/// - Works with the canonical Real from traits.zig.
const std = @import("std");
const traits = @import("traits.zig");
pub const Real = traits.Real;

/// Absolute tolerance check: |x - y| <= atol
pub fn almostEqualAbs(x: Real, y: Real, atol: Real) bool {
    return @abs(x - y) <= atol;
}

/// Relative tolerance check with clamp by maxAbs:
/// |x - y| <= max(rtol * max(|x|, |y|), maxAbs)
pub fn almostEqualRel(x: Real, y: Real, rtol: Real, maxAbs: Real) bool {
    const ax = @abs(x);
    const ay = @abs(y);
    const scale = if (ax > ay) ax else ay;
    const thresh = @max(rtol * scale, maxAbs);
    return @abs(x - y) <= thresh;
}

/// Unified "close" predicate: standard defaults suitable for most tests.
pub fn isClose(x: Real, y: Real) bool {
    const rtol: Real = if (Real == f32) 1e-6 else 1e-12;
    const atol: Real = if (Real == f32) 1e-7 else 1e-14;
    return almostEqualRel(x, y, rtol, atol);
}

/// ULP distance (non-negative). NaN returns max; +/-inf map to large values.
pub fn ulpDistance(x: Real, y: Real) u64 {
    if (!std.math.isFinite(x) or !std.math.isFinite(y)) {
        return std.math.maxInt(u64);
    }
    if (Real == f32) {
        const ix = floatKey32(@as(u32, @bitCast(x)));
        const iy = floatKey32(@as(u32, @bitCast(y)));
        const diff: u32 = if (ix > iy) ix - iy else iy - ix;
        return @as(u64, diff);
    } else { // f64
        const ix = floatKey64(@as(u64, @bitCast(x)));
        const iy = floatKey64(@as(u64, @bitCast(y)));
        return if (ix > iy) ix - iy else iy - ix;
    }
}

inline fn floatKey32(bits: u32) u32 {
    // Map IEEE754 to lexicographic ordering by magnitude with sign handled.
    return if ((bits & 0x8000_0000) != 0) ~bits + 1 else bits | 0x8000_0000;
}

inline fn floatKey64(bits: u64) u64 {
    return if ((bits & 0x8000_0000_0000_0000) != 0) ~bits + 1 else bits | 0x8000_0000_0000_0000;
}

/// Clamp x into [lo, hi] (no NaN guard).
pub fn clamp(x: Real, lo: Real, hi: Real) Real {
    return if (x < lo) lo else if (x > hi) hi else x;
}

/// Clamp into [0,1].
pub fn clamp01(t: Real) Real {
    return clamp(t, 0, 1);
}

/// Linear interpolation: a + t*(b - a). No fused multiply-add to keep determinism uniform.
pub fn lerp(a: Real, b: Real, t: Real) Real {
    return a + t * (b - a);
}

/// Near-zero predicate: |x| <= tol (default ~sqrt(eps)).
pub fn nearZero(x: Real) bool {
    const tol: Real = if (Real == f32) 1.5e-4 else 1.2e-8;
    return @abs(x) <= tol;
}

test "util: abs/rel closeness" {
    try std.testing.expect(almostEqualAbs(@as(Real, 1.0), 1.0 + 1e-15, 1e-14));
    try std.testing.expect(isClose(@as(Real, 1.0), 1.0 + 1e-13));
}

test "util: ulpDistance basic" {
    const d = ulpDistance(@as(Real, 1.0), @as(Real, 1.0));
    try std.testing.expect(d == 0);
}

test "util: clamp/lerp" {
    try std.testing.expect(clamp01(@as(Real, -0.5)) == 0);
    try std.testing.expect(clamp01(@as(Real, 1.5)) == 1);
    const v = lerp(@as(Real, 0.0), 10, 0.25);
    try std.testing.expect(v == 2.5);
}
