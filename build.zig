const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "eightb-cage-symplectic",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Establish external audit include and linking maps
    exe.addIncludePath(b.path("include"));
    exe.addLibraryPath(b.path("julia")); 
    exe.linkSystemLibrary("geometric_cage");
    exe.linkLibC();

    b.installArtifact(exe);
}
