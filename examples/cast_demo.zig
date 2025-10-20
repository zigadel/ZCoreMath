const std = @import("std");
const ZC = @import("ZCoreMath");

pub fn main() !void {
    // Checked cast (errors on overflow / NaN)
    const ok_i8 = try ZC.cast.toIntChecked(i8, 120);
    std.debug.print("checked i8 from 120 -> {d}\n", .{ok_i8});

    const too_big = ZC.cast.toIntChecked(i8, 200);
    if (too_big) |v| {
        std.debug.print("unexpected success: {d}\n", .{v});
    } else |err| {
        std.debug.print("checked i8 from 200 -> error: {s}\n", .{@errorName(err)});
    }

    // Saturating cast (clamps)
    const sat_hi: i8 = ZC.cast.toIntSaturate(i8, 1_000_000);
    const sat_lo: i8 = ZC.cast.toIntSaturate(i8, -1_000_000);
    std.debug.print("saturate i8 from 1e6  -> {d}\n", .{sat_hi});
    std.debug.print("saturate i8 from -1e6 -> {d}\n", .{sat_lo});

    // Float → int (checked & saturating)
    const f_ok = try ZC.cast.toIntChecked(i16, 123.0);
    const f_sat = ZC.cast.toIntSaturate(i16, -9e9);
    std.debug.print("checked i16 from 123.0 -> {d}\n", .{f_ok});
    std.debug.print("saturate i16 from -9e9 -> {d}\n", .{f_sat});
}
