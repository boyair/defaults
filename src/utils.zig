pub const ApplicationPath = "/usr/share/applications";
pub fn destroyStringArray(array: *std.ArrayList([]const u8), allocator: std.mem.Allocator) void {
    for (array.items) |string| {
        allocator.free(string);
    }
    array.deinit(allocator);
}

pub fn globalApplocationsDir(init: std.process.Init) !std.Io.Dir {
    return std.Io.Dir.openDirAbsolute(init.io, ApplicationPath, .{ .iterate = true });
}
pub fn homeSubDir(init: std.process.Init, sub_path: []const u8) !std.Io.Dir {
    const home_path = init.environ_map.get("HOME");
    const final_path = try std.fs.path.join(init.arena.allocator(), &.{ home_path.?, sub_path });
    return std.Io.Dir.openDirAbsolute(init.io, final_path, .{});
}

pub fn updateConfig(apps: DefaultApps, config_dir: std.Io.Dir, io: std.Io) !void {
    var buf: [4096]u8 = undefined;
    const config_file = try config_dir.createFile(io, "defaults.csv", .{});
    defer config_file.close(io);
    var config_writer = config_file.writer(io, &buf);
    try apps.print(&config_writer.interface, ',');
    try config_writer.flush();
}

pub fn cloneString(original: []const u8, allocator: std.mem.Allocator) error{OutOfMemory}![]u8 {
    const ret = try allocator.alloc(u8, original.len);
    @memcpy(ret, original);
    return ret;
}
/// USE IN TESTS ONLY!
pub const Test = struct {
    /// opens a file in the test folder.
    pub fn openFile(name: []const u8, options: std.Io.Dir.OpenFileOptions) !std.Io.File {
        const io = std.testing.io;
        const path = try std.fs.path.join(std.testing.allocator, &.{ "test", name });
        defer std.testing.allocator.free(path);
        const file = try std.Io.Dir.cwd().openFile(io, path, options);
        return file;
    }
};
const std = @import("std");
const parse = @import("parse.zig");
const DefaultApps = @import("defaultApps.zig");
