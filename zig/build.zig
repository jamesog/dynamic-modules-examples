const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the SDK module
    const sdk_module = b.addModule("envoy-dynamic-modules", .{
        .root_source_file = b.path("sdk/lib.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Add include path for abi.h (SDK references headers in same directory)
    sdk_module.addIncludePath(b.path("sdk"));

    // Build the shared library with all examples
    const lib = b.addSharedLibrary(.{
        .name = "zig_module",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.root_module.addImport("envoy-dynamic-modules", sdk_module);

    b.installArtifact(lib);

    // Create tests
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    main_tests.linkLibC();
    main_tests.root_module.addImport("envoy-dynamic-modules", sdk_module);

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
