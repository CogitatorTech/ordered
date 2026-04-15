const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const io = b.graph.io;

    const lib_source = b.path("src/lib.zig");
    const lib_module = b.addModule("ordered", .{
        .root_source_file = lib_source,
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .name = "ordered",
        .root_module = lib_module,
    });
    b.installArtifact(lib);

    // --- Docs Setup ---
    const docs_step = b.step("docs", "Generate API documentation");
    const doc_install_path = "docs/api";

    // Zig's `-femit-docs=<path>` writes the leaf dir but does not create
    // intermediate parents, and git does not track empty directories, so a
    // fresh checkout may have no `docs/` at all. Create it portably here
    // (idempotent: createDirPath is a no-op when the directory already exists).
    const ensure_docs_dir = EnsureDirStep.create(b, "docs");
    const gen_docs_cmd = b.addSystemCommand(&[_][]const u8{
        b.graph.zig_exe,
        "build-lib",
        "src/lib.zig",
        "-femit-docs=" ++ doc_install_path,
        "-fno-emit-bin",
    });
    gen_docs_cmd.step.dependOn(&ensure_docs_dir.step);
    docs_step.dependOn(&gen_docs_cmd.step);

    // --- Tests ---
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_module,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // --- Examples ---
    const examples_path = "examples";
    if (b.build_root.handle.openDir(io, examples_path, .{ .iterate = true })) |examples_dir| {
        var dir = examples_dir;
        defer dir.close(io);
        const run_all_examples = b.step("run-all", "Run all examples");
        var it = dir.iterate();
        while (it.next(io) catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
            const exe_name = entry.name[0 .. entry.name.len - 4];
            const exe_path = b.fmt("{s}/{s}", .{ examples_path, entry.name });
            const exe_module = b.addModule(exe_name, .{
                .root_source_file = b.path(exe_path),
                .target = target,
                .optimize = optimize,
            });
            exe_module.addImport("ordered", lib_module);
            const exe = b.addExecutable(.{
                .name = exe_name,
                .root_module = exe_module,
            });
            b.installArtifact(exe);
            const run_cmd = b.addRunArtifact(exe);
            const run_step_name = b.fmt("run-{s}", .{exe_name});
            const run_step_desc = b.fmt("Run the {s} example", .{exe_name});
            const run_step = b.step(run_step_name, run_step_desc);
            run_step.dependOn(&run_cmd.step);
            run_all_examples.dependOn(run_step);
        }
    } else |err| switch (err) {
        // Used as a library dependency: no examples directory at the import root.
        error.FileNotFound, error.NotDir => {},
        else => @panic(@errorName(err)),
    }

    // --- Benchmarks ---
    const benches_path = "benches";
    if (b.build_root.handle.openDir(io, benches_path, .{ .iterate = true })) |benches_dir| {
        var dir = benches_dir;
        defer dir.close(io);
        const bench_all = b.step("bench-all", "Run all benchmarks");
        var it = dir.iterate();
        while (it.next(io) catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
            const bench_name = entry.name[0 .. entry.name.len - 4];
            const bench_path = b.fmt("{s}/{s}", .{ benches_path, entry.name });
            const bench_module = b.addModule(bench_name, .{
                .root_source_file = b.path(bench_path),
                .target = target,
                .optimize = .ReleaseFast, // Use ReleaseFast for benchmarks
            });
            bench_module.addImport("ordered", lib_module);
            const bench_exe = b.addExecutable(.{
                .name = bench_name,
                .root_module = bench_module,
            });
            b.installArtifact(bench_exe);
            const run_bench_cmd = b.addRunArtifact(bench_exe);
            const bench_step_name = b.fmt("bench-{s}", .{bench_name});
            const bench_step_desc = b.fmt("Run the {s} benchmark", .{bench_name});
            const bench_step = b.step(bench_step_name, bench_step_desc);
            bench_step.dependOn(&run_bench_cmd.step);
            bench_all.dependOn(bench_step);
        }
    } else |err| switch (err) {
        error.FileNotFound, error.NotDir => {},
        else => @panic(@errorName(err)),
    }
}

/// Build step that ensures a directory (relative to the build root) exists.
/// Runs `std.fs.Dir.createDirPath` at make-time, so it only fires when a
/// step that depends on it is actually being built. Portable across Linux,
/// macOS, and Windows.
const EnsureDirStep = struct {
    step: std.Build.Step,
    sub_path: []const u8,

    fn create(b: *std.Build, sub_path: []const u8) *EnsureDirStep {
        const self = b.allocator.create(EnsureDirStep) catch @panic("OOM");
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = b.fmt("ensure {s}/", .{sub_path}),
                .owner = b,
                .makeFn = make,
            }),
            .sub_path = sub_path,
        };
        return self;
    }

    fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
        _ = options;
        const self: *EnsureDirStep = @fieldParentPtr("step", step);
        try step.owner.build_root.handle.createDirPath(step.owner.graph.io, self.sub_path);
    }
};
