const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const ev_module = b.addModule("ev", .{
        .source_file = .{ .path = "src/ev.zig" },
    });

    const lib = b.addStaticLibrary(.{
        .name = "ev",
        .target = target,
        .optimize = optimize,
    });
    const t = lib.target_info.target;
    lib.addCSourceFiles(&[_][]const u8{
        "src/ev.c",
        "src/event.c",
    }, &[_][]const u8{ "-Wall", "-Wno-int-conversion" });
    const config_h = b.addConfigHeader(.{
        .style = .blank,
        .include_path = "config.h",
    }, .{
        .HAVE_CLOCK_GETTIME = 1,
        .HAVE_DLFCN_H = 1,
        .HAVE_EPOLL_CTL = @intFromBool(t.os.tag != .macos),
        .HAVE_EVENTFD = @intFromBool(t.os.tag == .linux),
        .HAVE_FLOOR = 1,
        .HAVE_INOTIFY_INIT = @intFromBool(t.os.tag == .linux),
        .HAVE_INTTYPES_H = 1,
        .HAVE_KERNEL_RWF_T = 1,
        .HAVE_LINUX_AIO_ABI_H = @intFromBool(t.os.tag == .linux),
        .HAVE_LINUX_FS_H = @intFromBool(t.os.tag == .linux),
        .HAVE_MEMORY_H = 1,
        .HAVE_NANOSLEEP = @intFromBool(t.os.tag != .windows),
        .HAVE_POLL = @intFromBool(t.os.tag != .windows),
        .HAVE_POLL_H = 1,
        .HAVE_SELECT = 1,
        .HAVE_SIGNALFD = @intFromBool(t.os.tag == .linux),
        .HAVE_STDINT_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STRINGS_H = 1,
        .HAVE_STRING_H = 1,
        .HAVE_SYS_EPOLL_H = @intFromBool(t.os.tag != .macos),
        .HAVE_SYS_EVENTFD_H = @intFromBool(t.os.tag == .linux),
        .HAVE_SYS_INOTIFY_H = @intFromBool(t.os.tag == .linux),
        .HAVE_SYS_SELECT_H = 1,
        .HAVE_SYS_SIGNALFD_H = @intFromBool(t.os.tag == .linux),
        .HAVE_SYS_STAT_H = 1,
        .HAVE_SYS_TIMERFD_H = @intFromBool(t.os.tag == .linux),
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_KQUEUE = @intFromBool(t.os.tag == .macos),
        .HAVE_UNISTD_H = 1,
        .PACKAGE = "libev",
        .PACKAGE_BUGREPORT = "",
        .PACKAGE_NAME = "libev",
        .PACKAGE_STRING = "libev 4.33",
        .PACKAGE_TARNAME = "libev",
        .PACKAGE_URL = "",
        .PACKAGE_VERSION = "4.33",
        .STDC_HEADERS = 1,
        .VERSION = "4.33",
    });

    if (t.os.tag == .windows) {
        lib.addCSourceFile(.{
            .file = .{ .path = "src/wepoll.c" },
            .flags = &[_][]const u8{"-Wno-int-conversion"},
        });
        lib.linkSystemLibrary("ws2_32");
    }

    lib.addIncludePath(.{ .path = "src" });
    lib.addConfigHeader(config_h);
    lib.linkLibC();

    lib.installHeader("src/ev.h", "ev.h");
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "test/tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.linkLibrary(lib);
    main_tests.addModule("ev", ev_module);

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
