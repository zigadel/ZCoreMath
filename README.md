# ZCoreMath

**Lowest-layer utilities for all ZMath libs.**  
Small, deterministic building blocks: numeric traits, constants, safe casts, closeness/ULP helpers, tiny range iterators, and policy-based (decimal/dozenal) **formatting for diagnostics only**.

- Deterministic (no RNG/time/syscalls/threads)
- Allocator-explicit only in `fmt/*`; kernels allocate nothing
- WASM-friendly, pure Zig

---

## What’s included

- `lib/traits.zig` — canonical `Real` (`f64` default) and `Index` (`usize`) + tiny helpers
- `lib/consts.zig` — fundamental constants (`PI`, `TAU`, `E`, …)
- `lib/util.zig` — abs/rel closeness, ULP distance, clamp/lerp, near-zero
- `lib/cast.zig` — explicit, safe casts (checked & saturating) int↔float
- `lib/range.zig` — deterministic index ranges and `Linspace`
- `fmt/format.zig` — decimal/dozenal formatting; **diagnostics only**

Public import surface (via `src/root.zig`):

```zig
pub const fmt    = struct { pub const format = @import("fmt/format.zig"); };
pub const consts = @import("lib/consts.zig");
pub const traits = @import("lib/traits.zig");
pub const util   = @import("lib/util.zig");
pub const cast   = @import("lib/cast.zig");
pub const range  = @import("lib/range.zig");
```

---

## Install

Add a dependency in your project’s `build.zig.zon`:

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

Wire the module in `build.zig` (Zig 0.16-dev module API):

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

---

## Quickstart

```zig
const std = @import("std");
const ZC  = @import("ZCoreMath");

pub fn main() !void {
    // Constants
    const tau = ZC.consts.TAU;

    // Closeness & ULPs
    const close = ZC.util.isClose(1.0, 1.0 + 1e-13);
    const ulps  = ZC.util.ulpDistance(1.0, 1.0);

    // Safe cast
    const v: i16 = try ZC.cast.toIntChecked(i16, 1234);

    // Linspace (inclusive endpoints)
    var L = ZC.range.Linspace.init(0, 1, 5); // 0, 0.25, 0.5, 0.75, 1
    while (L.next()) |x| _ = x;

    // Dozenal diagnostics (formatting allocates)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const A = gpa.allocator();

    const s = try ZC.fmt.format.formatFloatAlloc(A, 1.5, .dozenal, 4); // "1.6…"
    defer A.free(s);

    _ = .{ tau, close, ulps, v, s };
}
```

---

## Build

```bash
zig build test-all --summary all   # unit + integration + e2e
zig build examples                 # builds examples/* and installs to zig-out/bin
zig build wasm                     # builds if src/exports.zig exists
```

---

## Error model

- Kernels (`lib/*`) do **not** allocate and avoid error sets, except:
  - `cast.toIntChecked` → `error.Overflow` / `error.NaNInput`.
- Formatting (`fmt/format.zig`) is allocator-explicit and may return `error.OutOfMemory`.

---

## Compatibility

- Target toolchain: **Zig 0.16-dev** (new `std.Build` module API, one-arg builtins like `@intFromFloat`, `@floatFromInt`, `@abs`).

---

## License

MIT (or your chosen permissive license). See `LICENSE`.

---

## Changelog

See `CHANGELOG.md`. Current: **v0.1.0** – initial release.
