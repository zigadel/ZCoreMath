const std = @import("std");

// Re-export surface for ZCoreMath.
// Kernels in lib/ are allocation-free; fmt/ allocates only for diagnostics.
// Radix policy (decimal/dozenal) affects formatting only.

pub const fmt = struct {
    pub const format = @import("fmt/format.zig");
};
pub const consts = @import("lib/consts.zig");
pub const traits = @import("lib/traits.zig");
pub const util = @import("lib/util.zig");
pub const cast = @import("lib/cast.zig");
pub const range = @import("lib/range.zig");

// Minimal smoke test (unit tests live inline per Zig convention)
test "ZCoreMath root builds" {
    try std.testing.expect(true);
}
