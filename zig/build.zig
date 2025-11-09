const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // SDK module (vendored from envoyproxy/envoy/source/extensions/dynamic_modules/sdk/zig)
    // TODO: Once there's a dedicated envoy-dynamic-modules-zig-sdk repo, use build.zig.zon dependency
    const sdk = b.addModule("envoy-dynamic-modules", .{
        .root_source_file = b.path("sdk/lib.zig"),
    });
    sdk.addIncludePath(b.path("sdk"));

    // Examples module
    const lib = b.addSharedLibrary(.{
        .name = "zig_module",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.root_module.addImport("envoy-dynamic-modules", sdk);
    b.installArtifact(lib);

    // Create tests
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    main_tests.linkLibC();
    main_tests.root_module.addImport("envoy-dynamic-modules", sdk);

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
