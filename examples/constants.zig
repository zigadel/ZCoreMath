const std = @import("std");
const ZC = @import("ZCoreMath");

pub fn main() !void {
    const PI = ZC.consts.PI;
    const TAU = ZC.consts.TAU;
    const E = ZC.consts.E;

    std.debug.print("PI  = {d:.16}\n", .{PI});
    std.debug.print("TAU = {d:.16}\n", .{TAU});
    std.debug.print("E   = {d:.16}\n", .{E});

    const close = ZC.util.isClose(2.0 * PI, TAU);
    std.debug.print("2π ≈ τ ? {any}\n", .{close});

    // dozenal formatting (allocator-explicit)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const A = gpa.allocator();

    const dozenal = try ZC.fmt.format.formatFloatAlloc(A, 1.5, .dozenal, 2); // "1.6"
    defer A.free(dozenal);
    std.debug.print("1.5 (dozenal) = {s}\n", .{dozenal});
}
