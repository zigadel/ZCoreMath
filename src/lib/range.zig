/// ZCoreMath: range.zig
/// Tiny, deterministic range iterators (no allocation, WASM-friendly).
/// - Index ranges for integers
/// - Linspace for Real (inclusive endpoints)
const std = @import("std");
const traits = @import("traits.zig");
pub const Real = traits.Real;
pub const Index = traits.Index;

/// Half-open integer range [start, end) with step>0.
pub const Range = struct {
    start: Index,
    end: Index,
    step: Index = 1,
    i: Index = 0,

    pub fn init(start: Index, end: Index, step: Index) Range {
        std.debug.assert(step > 0);
        return .{ .start = start, .end = end, .step = step, .i = start };
    }

    pub fn next(self: *Range) ?Index {
        if (self.i >= self.end) return null;
        const out = self.i;
        self.i += self.step;
        return out;
    }

    pub fn reset(self: *Range) void {
        self.i = self.start;
    }
};

/// Inclusive integer range [start, end] with step>0.
pub const RangeInc = struct {
    start: Index,
    end: Index,
    step: Index = 1,
    i: Index = 0,

    pub fn init(start: Index, end: Index, step: Index) RangeInc {
        std.debug.assert(step > 0);
        return .{ .start = start, .end = end, .step = step, .i = start };
    }

    pub fn next(self: *RangeInc) ?Index {
        if (self.i > self.end) return null;
        const out = self.i;
        self.i += self.step;
        return out;
    }

    pub fn reset(self: *RangeInc) void {
        self.i = self.start;
    }
};

/// Count how many terms in [start, end) stepping by step>0, saturating on overflow.
pub fn rangeCount(start: Index, end: Index, step: Index) Index {
    if (start >= end) return 0;
    const span = end - start;
    const n = span / step + @intFromBool(span % step != 0);
    return n;
}

/// Linspace over Real: N points from a to b inclusive. Requires n>=2.
pub const Linspace = struct {
    a: Real,
    b: Real,
    n: Index,
    k: Index = 0,

    pub fn init(a: Real, b: Real, n: Index) Linspace {
        std.debug.assert(n >= 2);
        return .{ .a = a, .b = b, .n = n, .k = 0 };
    }

    pub fn next(self: *Linspace) ?Real {
        if (self.k >= self.n) return null;
        const t = @as(Real, @floatFromInt(self.k)) / @as(Real, @floatFromInt(self.n - 1));
        const v = self.a + (self.b - self.a) * t;
        self.k += 1;
        return v;
    }

    pub fn reset(self: *Linspace) void {
        self.k = 0;
    }
};

test "Range half-open" {
    var r = Range.init(2, 7, 2); // 2,4,6
    var sum: Index = 0;
    while (r.next()) |i| sum += i;
    try std.testing.expect(sum == 12);
}

test "Range inclusive" {
    var r = RangeInc.init(2, 7, 2); // 2,4,6
    var sum: Index = 0;
    while (r.next()) |i| sum += i;
    try std.testing.expect(sum == 12);
}

test "rangeCount" {
    try std.testing.expect(rangeCount(0, 10, 3) == 4); // 0,3,6,9
}

test "Linspace" {
    var ls = Linspace.init(0, 1, 5); // 0,0.25,0.5,0.75,1.0
    var c: Index = 0;
    while (ls.next()) |v| {
        _ = v;
        c += 1;
    }
    try std.testing.expect(c == 5);
}
