pub const ApplicationPath = "/usr/share/applications";

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

pub const Clap = struct {
    /// struct used to parse KEY=VALUE pairs
    pub const Parsers = .{ .str = clap.parsers.string, .set = parseSet };

    /// Parse KEY=VALUE pairs
    const SetPair = struct { key: []const u8, value: []const u8 };
    fn parseSet(in: []const u8) parse.ParseError!SetPair {
        const idx = std.mem.indexOf(u8, in, &.{'='}) orelse return parse.ParseError.TooFewItems;
        return .{ .key = in[0..idx], .value = in[idx + 1 ..] };
    }
};

const std = @import("std");
const parse = @import("parse.zig");
const clap = @import("clap");
const DefaultApps = @import("defaultApps.zig");
