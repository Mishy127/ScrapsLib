const std = @import("std");

const version = std.SemanticVersion{
    .major = 1,
    .minor = 0,
    .patch = 1,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const files = b.addWriteFiles();
    const settings_file = files.add("scraps_settings.zig", b.fmt(
        \\const std = @import("std");
        \\pub const version = std.SemanticVersion.parse("{any}") catch unreachable;
    , .{version}));

    const settings = b.createModule(.{
        .root_source_file = settings_file,
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("Scraps", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.link_libc = true;
    mod.linkSystemLibrary("icuuc", .{});
    mod.linkSystemLibrary("icuio", .{});
    mod.addImport("settings", settings);

    const lib = b.addStaticLibrary(.{
        .name = "Scraps",
        .root_module = mod,
    });

    b.installArtifact(lib);
}
