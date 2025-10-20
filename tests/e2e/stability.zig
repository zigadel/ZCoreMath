const std = @import("std");
const ZC = @import("ZCoreMath");

test "constants: basic sanity" {
    try std.testing.expect(ZC.consts.TAU == 2.0 * ZC.consts.PI);
    try std.testing.expect(ZC.consts.E > 2.7 and ZC.consts.E < 2.8);
}

test "util: isClose and ulpDistance deterministic" {
    const a: ZC.traits.Real = 1.0;
    const b: ZC.traits.Real = 1.0 + 1e-12;
    _ = ZC.util.isClose(a, b);
    const d = ZC.util.ulpDistance(a, a);
    try std.testing.expect(d == 0);
}

test "format: dozenal integers and floats (diagnostics only)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const A = gpa.allocator();

    const si = try ZC.fmt.format.formatIntAlloc(A, 144, .dozenal); // 12*12 = 100₁₂
    defer A.free(si);
    try std.testing.expect(std.mem.eql(u8, si, "100"));

    const sf = try ZC.fmt.format.formatFloatAlloc(A, 1.5, .dozenal, 2);
    defer A.free(sf);
    try std.testing.expect(std.mem.indexOf(u8, sf, "1.") != null);
}

test "range: half-open and inclusive" {
    var r = ZC.range.Range.init(0, 5, 2); // 0,2,4
    var sum: usize = 0;
    while (r.next()) |i| sum += i;
    try std.testing.expect(sum == 6);

    var ri = ZC.range.RangeInc.init(0, 5, 2); // 0,2,4
    sum = 0;
    while (ri.next()) |i| sum += i;
    try std.testing.expect(sum == 6);
}
