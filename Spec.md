# ZCoreMath Spec

**Status:** v0.1 (alpha)  
**Scope:** deterministic, dependency-free primitives used across ZMath:

- Traits (`Real`, `Index`) and helpers
- Constants
- Utilities: closeness, ULP distance, clamp/lerp, near-zero
- Explicit casts (checked/saturating) between ints/floats
- Ranges and linspace
- Formatting (decimal/dozenal) for diagnostics only

The public surface is re-exported from `src/root.zig`:

```zig
pub const fmt    = struct { pub const format = @import("fmt/format.zig"); };
pub const consts = @import("lib/consts.zig");
pub const traits = @import("lib/traits.zig");
pub const util   = @import("lib/util.zig");
pub const cast   = @import("lib/cast.zig");
pub const range  = @import("lib/range.zig");
```
(See repo tree and `build.zig`.)

---

## 1) Modules and APIs

### 1.1 `lib/traits.zig`

- `pub const Real: type = f64;`
- `pub const Index: type = usize;`
- `pub inline fn epsilon(comptime T: type) T` — IEEE machine epsilon for `T∈{f16,f32,f64,f128}`
- `pub inline fn isFinite(x: anytype) bool`
- `pub inline fn sign(x: anytype) comptime_int`

**Invariants**
- `epsilon(T) > 0` and matches mantissa width for IEEE754.

---

### 1.2 `lib/consts.zig`

Pure constants:
`PI`, `TAU`, `E`, `SQRT2`, `INV_SQRT2`, `LN2`, `LN10`, `GOLDEN`, `EULER_GAMMA`.

---

### 1.3 `lib/util.zig`

- `pub fn almostEqualAbs(x: Real, y: Real, atol: Real) bool`
- `pub fn almostEqualRel(x: Real, y: Real, rtol: Real, maxAbs: Real) bool`
- `pub fn isClose(x: Real, y: Real) bool`
- `pub fn ulpDistance(x: Real, y: Real) u64`
- `pub fn clamp(x: Real, lo: Real, hi: Real) Real`
- `pub fn clamp01(t: Real) Real`
- `pub fn lerp(a: Real, b: Real, t: Real) Real`
- `pub fn nearZero(x: Real) Real`

**Invariants**
- `ulpDistance(x,x) == 0` for finite `x`.

---

### 1.4 `lib/cast.zig`

```zig
pub const CastError = error{ Overflow, NaNInput };

pub fn toIntSaturate(comptime Dst: type, x: anytype) Dst;
pub fn toIntChecked(comptime Dst: type, x: anytype) CastError!Dst;
pub fn toFloatChecked(x: anytype) CastError!Real;
```

**Behavior**
- `toIntSaturate`: clamps to `[minInt(Dst), maxInt(Dst)]`; non-finite floats clamp to bound by sign.
- `toIntChecked`: `error.Overflow` if out of range; `error.NaNInput` for non-finite floats.
- `toFloatChecked`: `error.NaNInput` for non-finite.

---

### 1.5 `lib/range.zig`

- `pub const Range`: half-open `[start,end)` over `Index` with positive `step`
  - `pub fn init(start: Index, end: Index, step: Index) Range`
  - `pub fn next(self: *Range) ?Index`
- `pub const RangeInc`: inclusive `[start,end]` with positive `step`
  - `init`, `next` as above
- `pub const Linspace`: `n` points from `a` to `b` **inclusive** in `Real`
  - `pub fn init(a: Real, b: Real, n: Index) Linspace`
  - `pub fn next(self: *Linspace) ?Real`

**Invariants**
- `Range` and `RangeInc` require `step > 0` and do not overflow.
- `Linspace.init(a,b,n)` with `n >= 2` yields exactly `n` values; `first == a`, `last == b`.

---

### 1.6 `fmt/format.zig`

- `pub const RadixPolicy = enum { decimal, dozenal }`
- `pub fn formatIntAlloc(a: std.mem.Allocator, x: i128, policy: RadixPolicy) ![]u8`
- `pub fn formatUIntAlloc(a: std.mem.Allocator, x: u128, policy: RadixPolicy) ![]u8`
- `pub fn formatFloatAlloc(a: std.mem.Allocator, x: f64, policy: RadixPolicy, frac_digits: usize) ![]u8`

**Rules**
- Dozenal uses `T` for 10, `E` for 11; integers/fractions built arithmetically (no locale).
- Non-finite floats render as `"NaN"`, `"+Inf"`, `"-Inf"`.
- Formatting is for diagnostics only; kernels must not depend on it.

---

## 2) Determinism & WASM

- No syscalls; no locale; only `fmt/*` allocates.
- Branch-stable algorithms across targets; suitable for WASM builds.

---

## 3) Testing

- Inline unit tests live in each module.
- E2E (`tests/e2e/stability.zig`) and integration (`tests/integration/consumers.zig`) import the public surface.
- `zig build test-all` runs: root tests, per-file unit tests, integration, and e2e.

---

## 4) Build & CI

- `build.zig` uses Zig 0.16-dev module APIs; examples are installed via `addInstallArtifact` so `zig build examples` creates `zig-out/` binaries.
- CI should run: `zig fmt --check`, `zig build test-all`, `zig build examples`.

---

## 5) SemVer

Pre-1.0: breaking → **minor** bump; post-1.0: strict SemVer with deprecations.
