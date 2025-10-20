# ZCoreMath Developer Docs

Practical guidance and recipes for the shipping surface of **ZCoreMath**:
- `consts`, `traits`, `util`, `cast`, `range`
- `fmt/format` (diagnostic formatting only)

Target toolchain: **Zig 0.16-dev** (new `std.Build` module API and one-arg builtins).

---

## 0) Principles

- **Deterministic:** no RNG/time/syscalls/threads; identical inputs → identical outputs.
- **Allocator discipline:** only `fmt/format.zig` allocates; kernels in `lib/*` are allocation-free.
- **Policy at edges:** decimal vs. dozenal is a *formatting* decision; computation stays radix-agnostic.
- **Public surface only:** consumers import everything through `src/root.zig`.

Public re-exports (from `src/root.zig`):
```zig
pub const fmt    = struct { pub const format = @import("fmt/format.zig"); };
pub const consts = @import("lib/consts.zig");
pub const traits = @import("lib/traits.zig");
pub const util   = @import("lib/util.zig");
pub const cast   = @import("lib/cast.zig");
pub const range  = @import("lib/range.zig");
```

---

## 1) Traits & Constants

### 1.1 `traits.zig`
- `pub const Real: type = f64;` — canonical scalar
- `pub const Index: type = usize;` — loop/range index
- `pub inline fn epsilon(comptime T: type) T` — IEEE epsilon for `T∈{f16,f32,f64,f128}`
- `pub inline fn isFinite(x: anytype) bool`
- `pub inline fn sign(x: anytype) comptime_int`

**Recipe: switch the project to single precision**
```zig
// In traits.zig
pub const Real: type = f32;
```
Rebuild downstream crates to propagate the new scalar.

### 1.2 `consts.zig`
Pure constants (`PI`, `TAU`, `E`, `SQRT2`, `INV_SQRT2`, `LN2`, `LN10`, `GOLDEN`, `EULER_GAMMA`).

**Recipe: use constants with Real**
```zig
const ZC = @import("ZCoreMath");
const Real = ZC.traits.Real;
const circle = 2.0 * ZC.consts.PI * @as(Real, 1.5);
```

---

## 2) Utilities (`util.zig`)

- `almostEqualAbs(x, y, atol)`
- `almostEqualRel(x, y, rtol, maxAbs)`
- `isClose(x, y)` — sensible defaults based on `Real`
- `ulpDistance(x, y)` — returns `u64` distance in representable steps
- `clamp(x, lo, hi)` / `clamp01(t)`
- `lerp(a, b, t)`
- `nearZero(x)`

**Recipe: safe assertions**
```zig
const ZC = @import("ZCoreMath");

test "stable closeness" {
    try std.testing.expect(ZC.util.isClose(1.0, 1.0 + 1e-13));
    try std.testing.expect(ZC.util.ulpDistance(1.0, 1.0) == 0);
}
```

**Tip:** prefer `isClose` for behavior, `ulpDistance` for diagnostics/regressions.

---

## 3) Explicit Casts (`cast.zig`)

```zig
pub const CastError = error{ Overflow, NaNInput };

pub fn toIntSaturate(comptime Dst: type, x: anytype) Dst;
pub fn toIntChecked(comptime Dst: type, x: anytype) CastError!Dst;
pub fn toFloatChecked(x: anytype) CastError!ZC.traits.Real;
```

- **Saturating**: clamps to legal range; non-finite floats clamp to bound by sign.
- **Checked**: returns `error.Overflow` or `error.NaNInput` instead of clamping.
- Handles `int/float` and `comptime_int/comptime_float` sources.

**Recipes**
```zig
const ZC = @import("ZCoreMath");

fn parseCount(x: anytype) !u16 {
    // Reject out-of-range instead of clamping
    return try ZC.cast.toIntChecked(u16, x);
}

fn clampToByte(x: anytype) u8 {
    // Clamp intentionally (e.g., visualization buckets)
    return ZC.cast.toIntSaturate(u8, x);
}

test "float->int checked" {
    try std.testing.expectError(ZC.cast.CastError.NaNInput, ZC.cast.toIntChecked(i32, std.math.nan(f64)));
}
```

---

## 4) Ranges & Linspace (`range.zig`)

- `Range`: half-open `[start, end)`, `step > 0`
  - `init(start: Index, end: Index, step: Index)`
  - `next() ?Index`
- `RangeInc`: inclusive `[start, end]`, `step > 0`
- `Linspace`: `n` evenly spaced points including endpoints in `Real`
  - `init(a: Real, b: Real, n: Index)` — `n>=2`
  - `next() ?Real`

**Recipes**
```zig
const ZC = @import("ZCoreMath");

test "range sum" {
    var r = ZC.range.Range.init(0, 10, 3); // 0,3,6,9
    var s: usize = 0;
    while (r.next()) |i| s += i;
    try std.testing.expect(s == 18);
}

test "linspace endpoints" {
    var L = ZC.range.Linspace.init(0, 1, 5);
    var first_ok = false;
    var last: ZC.traits.Real = undefined;
    while (L.next()) |x| {
        if (!first_ok) { try std.testing.expect(x == 0); first_ok = true; }
        last = x;
    }
    try std.testing.expect(last == 1);
}
```

**Edge guidance**
- For large integer spans use `Range`/`RangeInc`; for numeric sampling use `Linspace` with `Real`.
- `Linspace` steps are computed to include both endpoints exactly (within floating tolerances).

---

## 5) Diagnostic Formatting (`fmt/format.zig`)

- `RadixPolicy = enum { decimal, dozenal }`
- `formatIntAlloc(alloc, i128, policy)`
- `formatUIntAlloc(alloc, u128, policy)`
- `formatFloatAlloc(alloc, f64, policy, frac_digits)`

**Rules**
- Dozenal digits: `0..9,T,E` (10→`T`, 11→`E`).
- Non-finite: `"NaN"`, `"+Inf"`, `"-Inf"`.
- For **diagnostics/logs only**; kernels should not depend on string formatting.

**Recipe**
```zig
const std = @import("std");
const ZC  = @import("ZCoreMath");

test "dozenal format" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const A = gpa.allocator();

    const s = try ZC.fmt.format.formatIntAlloc(A, 144, .dozenal); // "100"
    defer A.free(s);
    try std.testing.expect(std.mem.eql(u8, s, "100"));
}
```

---

## 6) Consumer Integration

**`build.zig.zon`**
```zig
.{
    .name = "your-project",
    .version = "0.1.0",
    .dependencies = .{
        .ZCoreMath = .{
            .url = "https://github.com/<you>/ZCoreMath/archive/refs/tags/v0.1.0.tar.gz",
            .hash = "<fill-after-first-fetch>",
        },
    },
}
```

**`build.zig`**
```zig
const zcore = b.dependency("ZCoreMath", .{ .target = target, .optimize = optimize });
const ZCoreMath = zcore.module("ZCoreMath");

const exe = b.addExecutable(.{
    .name = "your-bin",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ZCoreMath", .module = ZCoreMath },
        },
    }),
});
b.addInstallArtifact(exe, .{});
```

**Use in code**
```zig
const ZC = @import("ZCoreMath");
```

---

## 7) Testing Matrix

Your repo’s `build.zig` composes:
- **Root tests** on the public module
- **Per-file unit tests** for `lib/cast.zig`, `lib/util.zig`, `fmt/format.zig`
- **Integration**: `tests/integration/consumers.zig`
- **E2E**: `tests/e2e/stability.zig`

Run everything:
```bash
zig build test-all --summary all
```

**CI** should run:
```bash
zig fmt --check .
zig build test-all --summary all
zig build examples
```

---

## 8) Troubleshooting

- **No `zig-out/` after building examples**: ensure `addInstallArtifact` is used and the `examples` step depends on the *install* step. (Your current `build.zig` does this.)
- **Snapshot mismatches**: if you see errors about `@floatToInt`/`@intCast` with two args, you’re on older Zig; this project uses 0.16-style builtins (`@intFromFloat`, `@floatFromInt`, one-arg `@intCast`, `@abs`).

---

## 9) Roadmap Hints (non-binding)

- Potential `numeric/*` and `base12/*` modules come later at higher levels (`ZExact`, `ZNumeric`, etc.).
- This core deliberately stays small, deterministic, and allocator-light.
