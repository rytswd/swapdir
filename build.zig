const std = @import("std");

const version = "0.1.0";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Resolve the git commit embedded in `--version`. Priority:
    //   1. -Dgit_rev=...  (set by Nix/CI from the flake revision; the Nix
    //      sandbox has no .git, so it must be passed in explicitly)
    //   2. `git rev-parse` for local source-tree builds
    //   3. "unknown" fallback
    const git_rev = b.option([]const u8, "git_rev", "Git commit hash to embed in --version") orelse
        gitRev(b) orelse "unknown";

    const build_info = b.addOptions();
    build_info.addOption([]const u8, "version", version);
    build_info.addOption([]const u8, "git_rev", git_rev);

    // Main executable
    const exe = b.addExecutable(.{
        .name = "swapdir",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_info", build_info);
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run swapdir");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const exe_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe_tests.root_module.addOptions("build_info", build_info);
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

/// Best-effort read of the short git commit hash for local builds.
/// Returns null when git is unavailable or this is not a git checkout.
fn gitRev(b: *std.Build) ?[]const u8 {
    var code: u8 = undefined;
    const out = b.runAllowFail(
        &.{ "git", "rev-parse", "--short", "HEAD" },
        &code,
        .ignore,
    ) catch return null;
    const trimmed = std.mem.trim(u8, out, " \t\r\n");
    return if (trimmed.len == 0) null else trimmed;
}
