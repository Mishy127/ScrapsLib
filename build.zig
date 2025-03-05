const std = @import("std");

const version = std.SemanticVersion{
    .major = 1,
    .minor = 0,
    .patch = 0,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const config = b.addOptions();
    config.addOption(std.SemanticVersion, "version", version);

    const mod = b.addModule("Scraps", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.linkSystemLibrary("icuuc", .{});
    mod.linkSystemLibrary("icuio", .{});
    mod.addOptions("config", config);

    const lib = b.addStaticLibrary(.{
        .name = "Scraps",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.linkSystemLibrary("icuuc");
    lib.linkSystemLibrary("icuio");
    lib.root_module.addOptions("config", config);

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.linkLibC();
    lib_unit_tests.linkSystemLibrary("icuuc");
    lib_unit_tests.linkSystemLibrary("icuio");
    lib_unit_tests.root_module.addOptions("config", config);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
