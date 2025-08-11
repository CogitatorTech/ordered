const std = @import("std");
const fs = std.fs;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
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
    const docs_step = b.step("docs", "Generate API documentation");
    const doc_install_path = "docs/api";
    const gen_docs_cmd = b.addSystemCommand(&[_][]const u8{
        b.graph.zig_exe,
        "build-lib",
        "src/lib.zig",
        "-femit-docs=" ++ doc_install_path,
    });
    const mkdir_cmd = b.addSystemCommand(&[_][]const u8{
        "mkdir", "-p", doc_install_path,
    });
    gen_docs_cmd.step.dependOn(&mkdir_cmd.step);
    docs_step.dependOn(&gen_docs_cmd.step);
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_module,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Build examples
    const examples_path = "examples";
    examples_blk: {
        var examples_dir = fs.cwd().openDir(examples_path, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound or err == error.NotDir) break :examples_blk;
            @panic("Can't open 'examples' directory");
        };
        defer examples_dir.close();
        var dir_iter = examples_dir.iterate();
        while (dir_iter.next() catch @panic("Failed to iterate examples")) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
            const exe_name = fs.path.stem(entry.name);
            const exe_path = b.fmt("{s}/{s}", .{ examples_path, entry.name });
            const exe_module = b.createModule(.{
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
        }
    }

    // Build benchmarks
    const benches_path = "benches";
    benches_blk: {
        var benches_dir = fs.cwd().openDir(benches_path, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound or err == error.NotDir) break :benches_blk;
            @panic("Can't open 'benches' directory");
        };
        defer benches_dir.close();
        var dir_iter = benches_dir.iterate();
        while (dir_iter.next() catch @panic("Failed to iterate benches")) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
            const bench_name = fs.path.stem(entry.name);
            const bench_path = b.fmt("{s}/{s}", .{ benches_path, entry.name });
            const bench_module = b.createModule(.{
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
        }
    }
}
