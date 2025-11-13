const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const lib_mod = b.addModule("zmdlib", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zmdlib",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const cli = b.dependency("cli", .{});

    const main_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    const Program = struct {
        name: [:0]const u8,
        path: [:0]const u8,
    };

    const programs = [_]Program{
        .{
            .name = "tohtml",
            .path = "tools/tohtml.zig",
        },
    };

    for (programs) |prog| {
        const program_mod = b.addModule(prog.name, .{
            .root_source_file = b.path(prog.path),
            .target = target,
            .optimize = optimize,
        });

        const program = b.addExecutable(.{
            .name = prog.name,
            .root_module = program_mod,
        });
        program.root_module.addImport("zmdlib", lib_mod);
        program.root_module.addImport("cli", cli.module("zcliconfig"));

        b.installArtifact(program);
        b.default_step.dependOn(&program.step);
    }
}
