const std = @import("std");

inline fn fileExists(path: []const u8) bool {
    // statFile() succeeds (returns a Stat) or throws; we map that to bool.
    _ = std.fs.cwd().statFile(path) catch return false;
    return true;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ------------------------------------------------------------------------
    // Public module: expose src/root.zig as "ZCoreMath"
    // ------------------------------------------------------------------------
    const zcore_module = b.addModule("ZCoreMath", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ------------------------------------------------------------------------
    // Tests (unit + integration + e2e)
    // ------------------------------------------------------------------------
    const step_test = b.step("test", "Run unit + e2e + integration tests");
    const step_test_all = b.step("test-all", "Alias for test");
    step_test_all.dependOn(step_test);

    // Root inline tests across src/*
    {
        const root_tests = b.addTest(.{ .root_module = zcore_module });
        const run_root = b.addRunArtifact(root_tests);
        step_test.dependOn(&run_root.step);
    }

    // Dedicated per-file unit tests for modules that contain inline tests
    const unit_step = b.step("test-unit", "Run inline unit tests from module files");

    // cast.zig
    if (fileExists("src/lib/cast.zig")) {
        const m = b.createModule(.{
            .root_source_file = b.path("src/lib/cast.zig"),
            .target = target,
            .optimize = optimize,
        });
        const t = b.addTest(.{ .root_module = m });
        const r = b.addRunArtifact(t);
        unit_step.dependOn(&r.step);
    }

    // util.zig
    if (fileExists("src/lib/util.zig")) {
        const m = b.createModule(.{
            .root_source_file = b.path("src/lib/util.zig"),
            .target = target,
            .optimize = optimize,
        });
        const t = b.addTest(.{ .root_module = m });
        const r = b.addRunArtifact(t);
        unit_step.dependOn(&r.step);
    }

    // fmt/format.zig
    if (fileExists("src/fmt/format.zig")) {
        const m = b.createModule(.{
            .root_source_file = b.path("src/fmt/format.zig"),
            .target = target,
            .optimize = optimize,
        });
        const t = b.addTest(.{ .root_module = m });
        const r = b.addRunArtifact(t);
        unit_step.dependOn(&r.step);
    }

    // Aggregate unit tests into main test step
    step_test.dependOn(unit_step);

    // e2e
    if (fileExists("tests/e2e/stability.zig")) {
        const e2e_mod = b.createModule(.{
            .root_source_file = b.path("tests/e2e/stability.zig"),
            .target = target,
            .optimize = optimize,
        });
        e2e_mod.addImport("ZCoreMath", zcore_module);
        const e2e = b.addTest(.{ .root_module = e2e_mod });
        const e2e_run = b.addRunArtifact(e2e);
        step_test.dependOn(&e2e_run.step);
    }

    // integration
    if (fileExists("tests/integration/consumers.zig")) {
        const integ_mod = b.createModule(.{
            .root_source_file = b.path("tests/integration/consumers.zig"),
            .target = target,
            .optimize = optimize,
        });
        integ_mod.addImport("ZCoreMath", zcore_module);
        const integ = b.addTest(.{ .root_module = integ_mod });
        const integ_run = b.addRunArtifact(integ);
        step_test.dependOn(&integ_run.step);
    }

    // ------------------------------------------------------------------------
    // Examples — set .target / .optimize on the module itself (0.16-dev)
    // ------------------------------------------------------------------------
    const step_examples = b.step("examples", "Build examples/* executables");

    if (fileExists("examples/constants.zig")) {
        const exe = b.addExecutable(.{
            .name = "constants",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/constants.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "ZCoreMath", .module = zcore_module },
                },
            }),
        });
        const inst = b.addInstallArtifact(exe, .{});
        step_examples.dependOn(&inst.step);
    }

    if (fileExists("examples/cast_demo.zig")) {
        const exe = b.addExecutable(.{
            .name = "cast_demo",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/cast_demo.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "ZCoreMath", .module = zcore_module },
                },
            }),
        });
        const inst = b.addInstallArtifact(exe, .{});
        step_examples.dependOn(&inst.step);
    }

    if (fileExists("examples/ulp_demo.zig")) {
        const exe = b.addExecutable(.{
            .name = "ulp_demo",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/ulp_demo.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "ZCoreMath", .module = zcore_module },
                },
            }),
        });
        const inst = b.addInstallArtifact(exe, .{});
        step_examples.dependOn(&inst.step);
    }

    // ------------------------------------------------------------------------
    // Optional wasm demo — resolve the WASM target first
    // ------------------------------------------------------------------------
    const step_wasm = b.step("wasm", "Build wasm32-freestanding demo (exports.zig) if present");
    if (fileExists("src/exports.zig")) {
        const wasm_target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
            .abi = .none,
        });

        const wasm_exe = b.addExecutable(.{
            .name = "zcoremath_wasm",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/exports.zig"),
                .target = wasm_target,
                .optimize = .ReleaseSmall,
                .imports = &.{
                    .{ .name = "ZCoreMath", .module = zcore_module },
                },
            }),
        });
        const wasm_inst = b.addInstallArtifact(wasm_exe, .{});
        step_wasm.dependOn(&wasm_inst.step);
    }
}
