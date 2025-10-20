# ZCoreMath — Project Structure Plan (ideal)
Updated: 2025-10-20

Single source of truth for the intended directory/file layout. We will create actual files **one-by-one**
after this (README → Spec → Docs), matching this structure.

```sh
ZCoreMath/
├─ build.zig                 # build library + tests + examples; wasm-friendly options
├─ build.zon                 # package manifest (name, version, deps)
├─ README.md                 # overview & quickstart (next to generate)
├─ ZCoreMath.Spec.md         # authoritative API
├─ ZCoreMath.Docs.md         # developer recipes & guidance
├─ src/
│  ├─ root.zig               # single import surface; re-exports modules below
│  ├─ lib/
│  │  ├─ consts.zig          # math/physical constants (pure, no allocation)
│  │  ├─ traits.zig          # type aliases (Real/Index), compile-time helpers
│  │  ├─ util.zig            # eps/ulp/close-to, safe comparisons
│  │  ├─ cast.zig            # explicit, checked casts; saturating/rounding helpers
│  │  └─ range.zig           # tiny range iterators (deterministic, bounds-checked)
│  ├─ fmt/
│  │  └─ format.zig          # radix-policy (decimal/dozenal) diagnostics only
│  └─ cli/
│     └─ zcore.zig           # optional CLI (no syscalls in kernels)
├─ examples/
│  ├─ ulp_demo.zig           # compare ulp distances; print via fmt
│  ├─ cast_demo.zig          # show saturating/checked casts
│  └─ constants.zig          # PI/TAU/E sample
├─ docs/
│  └─ refs.md                # references for numeric policies (IEEE, rounding modes)
├─ tests/
│  ├─ e2e/
│  │  └─ stability.zig       # deterministic stability/ulp fixtures
│  └─ integration/
│     └─ consumers.zig       # smoke tests for downstream libs importing ZCoreMath
```

## Conventions (Zigadel-wide)
- **Allocator-explicit**: kernels allocate nothing; only `fmt/*` allocates for strings.
- **Deterministic**: no RNG/time/syscalls/threads; identical inputs → identical outputs.
- **WASM-first**: flat APIs, bounded stack, no recursion.
- **Radix policy**: affects **only** formatting; numerical code never branches on it.
- **Import direction**: lowest layer; nothing from ZMath imports this library.

## Planned module surface (via `src/root.zig`)
```zig
pub const fmt    = struct { pub const format = @import("fmt/format.zig"); };
pub const consts = @import("lib/consts.zig");
pub const traits = @import("lib/traits.zig");
pub const util   = @import("lib/util.zig");
pub const cast   = @import("lib/cast.zig");
pub const range  = @import("lib/range.zig");
```

## Build targets (planned)
- `zig build test` — run unit tests embedded inside `.zig` sources.
- `zig build examples` — compile examples; no syscalls in kernels.
- `zig build -Dtarget=wasm32-freestanding -Doptimize=ReleaseSmall` — tiny `.wasm` for `.dcz`.

## Next step
Per your rule: **one file at a time**. Say “README next” and I’ll generate `ZCoreMath/README.md`.
