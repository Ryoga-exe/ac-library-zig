const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("ac-library", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "ac-library",
        .root_module = mod,
    });

    b.installArtifact(lib);

    const docs_step = b.step("docs", "Generate docs");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    const test_step = b.step("test", "Run library tests");
    const unit_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);

    const examples_step = b.step("examples", "Build examples");

    var examples_dir = try std.fs.cwd().openDir("examples/", .{ .iterate = true });
    defer examples_dir.close();
    var walker = try examples_dir.walk(b.allocator);
    defer walker.deinit();
    const proconio = b.lazyDependency("proconio", .{});
    while (try walker.next()) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".zig")) {
            continue;
        }
        const example_name = entry.basename[0 .. entry.basename.len - 4];
        const example = b.addExecutable(.{
            .name = example_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("examples/{s}", .{entry.path})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "ac-library", .module = mod },
                    .{ .name = "proconio", .module = proconio.?.module("proconio") },
                },
            }),
        });
        const sub_path = entry.path[0 .. entry.path.len - 4];
        const install_example = b.addInstallArtifact(example, .{ .dest_sub_path = b.fmt("{s}", .{sub_path}) });
        examples_step.dependOn(&example.step);
        examples_step.dependOn(&install_example.step);
    }

    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(docs_step);
    all_step.dependOn(test_step);
    all_step.dependOn(examples_step);
}
