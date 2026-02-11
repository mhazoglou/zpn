const std = @import("std");

// This was used to check building across platforms

// const targets: []const std.Target.Query = &.{
//     .{ .cpu_arch = .aarch64, .os_tag = .macos },
//     .{ .cpu_arch = .aarch64, .os_tag = .linux },
//     .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
//     .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
//     .{ .cpu_arch = .x86_64, .os_tag = .windows },
// };
// 
// pub fn build(b: *std.Build) !void {
//     for (targets) |t| {
//         const exe = b.addExecutable(.{
//             .name = "zpn",
//             .root_module = b.createModule(.{
//                 .root_source_file = b.path("./src/main.zig"),
//                 .target = b.resolveTargetQuery(t),
//                 .optimize = .ReleaseSafe,
//             }),
//         });
// 
//         const target_output = b.addInstallArtifact(exe, .{
//             .dest_dir = .{
//                 .override = .{
//                     .custom = try t.zigTriple(b.allocator),
//                 },
//             },
//         });
// 
//         b.getInstallStep().dependOn(&target_output.step);
//     }
// }

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zpn", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "zpn",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zpn", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

}
