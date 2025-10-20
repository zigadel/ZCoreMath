/// ZCoreMath: fmt/format.zig
/// Radix-policy diagnostics (decimal/dozenal) — allocator-explicit, deterministic, WASM-friendly.
/// NOTE: Formatting is for human-readable diagnostics only. Numerical kernels must not depend on it.
const std = @import("std");

pub const RadixPolicy = enum { decimal, dozenal };

const DEC_DIGITS = "0123456789";
const DOZ_DIGITS = "0123456789TE"; // T=ten, E=eleven

inline fn digitChar(radix: RadixPolicy, d: u8) u8 {
    return switch (radix) {
        .decimal => DEC_DIGITS[@as(usize, d)],
        .dozenal => DOZ_DIGITS[@as(usize, d)],
    };
}

/// Safe |x| for i128 as u128 (handles min-int without overflow)
inline fn abs128u(x: i128) u128 {
    if (x >= 0) return @as(u128, @intCast(x));
    const one_less = x + 1;
    const mag = @as(u128, @intCast(-one_less));
    return mag + 1;
}

/// Format a signed integer with the given policy.
pub fn formatIntAlloc(a: std.mem.Allocator, x: i128, policy: RadixPolicy) ![]u8 {
    if (policy == .decimal) {
        return std.fmt.allocPrint(a, "{d}", .{x});
    }

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(a);

    var n: u128 = abs128u(x);
    if (x < 0) try buf.append(a, '-');

    // Convert integer in base 12
    var tmp: [128]u8 = undefined;
    var i: usize = 0;
    if (n == 0) {
        tmp[i] = digitChar(.dozenal, 0);
        i += 1;
    } else {
        while (n > 0) : (n /= 12) {
            const d: u8 = @as(u8, @intCast(n % 12));
            tmp[i] = digitChar(.dozenal, d);
            i += 1;
        }
    }
    // reverse into buf
    var k: usize = i;
    while (k > 0) : (k -= 1) {
        try buf.append(a, tmp[k - 1]);
    }
    return buf.toOwnedSlice(a);
}

/// Format an unsigned integer with the given policy.
pub fn formatUIntAlloc(a: std.mem.Allocator, x: u128, policy: RadixPolicy) ![]u8 {
    if (policy == .decimal) {
        return std.fmt.allocPrint(a, "{d}", .{x});
    }

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(a);

    // Convert integer in base 12
    var tmp: [128]u8 = undefined;
    var i: usize = 0;
    var n = x;
    if (n == 0) {
        tmp[i] = digitChar(.dozenal, 0);
        i += 1;
    } else {
        while (n > 0) : (n /= 12) {
            const d: u8 = @as(u8, @intCast(n % 12));
            tmp[i] = digitChar(.dozenal, d);
            i += 1;
        }
    }
    var k: usize = i;
    while (k > 0) : (k -= 1) {
        try buf.append(a, tmp[k - 1]);
    }
    return buf.toOwnedSlice(a);
}

/// Format a floating-point value with a chosen radix. For dozenal, we generate an integer + fractional
/// representation with `frac_digits` places (no scientific notation). For decimal, we delegate to fmt.
pub fn formatFloatAlloc(a: std.mem.Allocator, x: f64, policy: RadixPolicy, frac_digits: usize) ![]u8 {
    return switch (policy) {
        .decimal => std.fmt.allocPrint(a, "{d}", .{x}),
        .dozenal => formatFloatDozenalAlloc(a, x, frac_digits),
    };
}

fn formatFloatDozenalAlloc(a: std.mem.Allocator, x: f64, frac_digits: usize) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(a);

    if (!std.math.isFinite(x)) {
        if (std.math.isNan(x)) {
            try buf.appendSlice(a, "NaN");
        } else if (x == std.math.inf(f64)) {
            try buf.appendSlice(a, "+Inf");
        } else {
            try buf.appendSlice(a, "-Inf");
        }
        return buf.toOwnedSlice(a);
    }

    var v = x;
    if (v < 0) {
        try buf.append(a, '-');
        v = -v;
    }

    // integer part
    const ip = @as(i128, @intFromFloat(@floor(v)));
    const s_int = try formatIntAlloc(a, ip, .dozenal);
    defer a.free(s_int);
    try buf.appendSlice(a, s_int);

    // fractional part
    const has_frac = v - @as(f64, @floatFromInt(ip)) > 0.0 and frac_digits > 0;
    if (has_frac) {
        try buf.append(a, '.');
        var frac = v - @as(f64, @floatFromInt(ip));
        var i: usize = 0;
        while (i < frac_digits) : (i += 1) {
            frac *= 12.0;
            var d: i32 = @as(i32, @intFromFloat(@floor(frac + 1e-15))); // tiny bias to stabilize
            if (d < 0) d = 0;
            if (d > 11) d = 11;
            try buf.append(a, digitChar(.dozenal, @as(u8, @intCast(d))));
            frac -= @as(f64, @floatFromInt(d));
        }
    }
    return buf.toOwnedSlice(a);
}

/// Format "label: value" using the chosen policy.
pub fn formatLabelValueAlloc(a: std.mem.Allocator, label: []const u8, x: f64, policy: RadixPolicy, frac_digits: usize) ![]u8 {
    const s = try formatFloatAlloc(a, x, policy, frac_digits);
    defer a.free(s);
    return std.fmt.allocPrint(a, "{s}: {s}", .{ label, s });
}

test "format: integers dozenal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const A = gpa.allocator();

    const s0 = try formatIntAlloc(A, 0, .dozenal);
    defer A.free(s0);
    try std.testing.expect(std.mem.eql(u8, s0, "0"));

    const s1 = try formatIntAlloc(A, 144, .dozenal); // 12*12
    defer A.free(s1);
    try std.testing.expect(std.mem.eql(u8, s1, "100"));
}

test "format: float dozenal basic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const A = gpa.allocator();

    const s = try formatFloatAlloc(A, 1.5, .dozenal, 4); // 1.6 in dozenal (0.5 * 12 = 6)
    defer A.free(s);
    try std.testing.expect(std.mem.indexOf(u8, s, ".") != null);
}
