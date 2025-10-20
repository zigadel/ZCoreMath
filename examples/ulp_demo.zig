const std = @import("std");
const ZC = @import("ZCoreMath");

pub fn main() !void {
    const R = ZC.traits.Real;

    // Show ULP distance around 1.0
    const a: R = 1.0;
    const b: R = 1.0 + (if (R == f32) 1.0e-7 else 1.0e-15);
    const c: R = 1.0 + (if (R == f32) 2.0e-7 else 2.0e-15);

    const d_ab = ZC.util.ulpDistance(a, b);
    const d_ac = ZC.util.ulpDistance(a, c);
    std.debug.print("ulpDistance(1.0, b) = {d}\n", .{d_ab});
    std.debug.print("ulpDistance(1.0, c) = {d}\n", .{d_ac});

    // Quick sweep: consecutive representables using nextAfter
    var i: usize = 0;
    var prev: R = a;
    while (i < 5) : (i += 1) {
        const next = std.math.nextAfter(R, prev, std.math.inf(R));
        const d = ZC.util.ulpDistance(prev, next);
        std.debug.print("nextAfter step {d}: ulp(prev,next) = {d}\n", .{ i, d });
        prev = next;
    }
}
