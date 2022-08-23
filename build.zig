const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    var tflitePkg = std.build.Pkg{
        .name = "tflite",
        .source = std.build.FileSource{ .path = "libs/zig-tflite/src/main.zig" },
    };
    var zigcvPkg = std.build.Pkg{
        .name = "zigcv",
        .source = std.build.FileSource{ .path = "libs/zigcv/src/main.zig" },
    };

    const exe = b.addExecutable("zig-tflite-example", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackage(tflitePkg);
    exe.addPackage(zigcvPkg);

    exe.addIncludePath("libs/zigcv/libs/gocv");
    exe.addCSourceFiles(&.{
        "libs/zigcv/libs/gocv/core.cpp",
        "libs/zigcv/libs/gocv/videoio.cpp",
        "libs/zigcv/libs/gocv/highgui.cpp",
        "libs/zigcv/libs/gocv/imgcodecs.cpp",
        "libs/zigcv/libs/gocv/objdetect.cpp",
        "libs/zigcv/libs/gocv/imgproc.cpp",
    }, &.{
        "--std=c++11",
    });
    switch (exe.target.toTarget().os.tag) {
        .windows => {
            exe.addIncludePath("c:/msys64/mingw64/include");
            exe.addIncludePath("c:/msys64/mingw64/include/c++/12.2.0");
            exe.addIncludePath("c:/msys64/mingw64/include/c++/12.2.0/x86_64-w64-mingw32");
            exe.addIncludePath("c:/opencv/build/install/include");
            exe.addLibraryPath("c:/msys64/mingw64/lib");
            exe.addLibraryPath("c:/opencv/build/install/x64/mingw/staticlib");
            exe.linkSystemLibrary("tensorflowlite-delegate_xnnpack");
            exe.linkSystemLibrary("tensorflowlite_c");
            exe.linkSystemLibrary("opencv4");
            exe.linkSystemLibrary("stdc++.dll");
            exe.linkSystemLibrary("unwind");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("c");
        },
        else => {
            exe.addIncludePath("/usr/local/include");
            exe.addIncludePath("/usr/local/include/opencv4");
            exe.addIncludePath("/opt/homebrew/include");
            exe.addIncludePath("/opt/homebrew/include/opencv4");
            exe.addLibraryPath("/usr/local/lib");
            exe.addLibraryPath("/usr/local/lib/opencv4/3rdparty");
            exe.addLibraryPath("/opt/homebrew/lib");
            exe.addLibraryPath("/opt/homebrew/lib/opencv4/3rdparty");
            exe.linkLibCpp();
            exe.linkSystemLibrary("tensorflowlite-delegate_xnnpack");
            exe.linkSystemLibrary("tensorflowlite_c");
            exe.linkSystemLibrary("opencv4");
            exe.linkSystemLibrary("unwind");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("c");
        },
    }
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
