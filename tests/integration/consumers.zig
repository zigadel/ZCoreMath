const std = @import("std");
const ZC = @import("ZCoreMath");

// This file simulates downstream usage (e.g., ZLinear/ZProbability) by
// consuming ZCoreMath's public surface only. No reliance on internal files.
test "consumer: use traits/consts/util without fmt" {
    // Kernels must not allocate. We do not create any allocator here.
    const Real = ZC.traits.Real;
    const two_pi: Real = @as(Real, 2.0) * ZC.consts.PI;
    try std.testing.expect(ZC.util.isClose(two_pi, ZC.consts.TAU));
    try std.testing.expect(ZC.util.ulpDistance(two_pi, ZC.consts.TAU) == 0);
}

test "consumer: safe casts and ranges compose" {
    // Simulate a tiny downstream numeric loop
    var sum_i: i64 = 0;
    var r = ZC.range.Range.init(0, 10, 3); // 0,3,6,9
    while (r.next()) |i| {
        const as_i32 = @as(i32, @intCast(i)); // 0.16-dev: one-arg @intCast with explicit dest via @as
        const v = try ZC.cast.toIntChecked(i64, as_i32);
        sum_i += v;
    }
    try std.testing.expect(sum_i == 18);
}

test "consumer: fmt is optional (diagnostics only)" {
    // Consumers may format numbers for logs, but kernels never call fmt.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const A = gpa.allocator();
    const s = try ZC.fmt.format.formatFloatAlloc(A, 1.5, .dozenal, 4);
    defer A.free(s);
    try std.testing.expect(std.mem.indexOf(u8, s, "1.") != null);
}
