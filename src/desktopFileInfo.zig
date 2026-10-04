const std = @import("std");
const Parse = @import("parse.zig");
const Utils = @import("utils.zig");
const Self = @This();

is_application: bool = false,
//TODO: add is_hidden parameter back once i know the syntex and what it does.
//is_hidden: bool = false,
command: ?[]const u8 = null,
categories: ?std.ArrayList([]const u8) = null,

pub fn initParse(reader: *std.Io.Reader, allocator: std.mem.Allocator) !Self {
    var ret: Self = .{};
    while (try reader.takeDelimiter('\n')) |line| {
        //TODO: replace this line once i know what to do with a title
        if (Parse.trim(line).len == 0 or line[0] == '[' or line[0] == '#') continue;
        try parseLine(line, allocator, &ret);
    }
    return ret;
}

fn parseLine(line: []const u8, allocator: std.mem.Allocator, self: *Self) !void {
    const trimmed = Parse.trim(line);
    const key_val = try Parse.KeyValuePair.init(trimmed);
    if (std.mem.eql(u8, key_val.key, "Type")) {
        self.is_application = std.mem.eql(u8, key_val.value, "Application");
    } else if (self.command == null and std.mem.eql(u8, key_val.key, "Exec")) {
        self.command = try Utils.cloneString(key_val.value, allocator);
    } else if (self.categories == null and std.mem.eql(u8, key_val.key, "Categories")) {
        var it = std.mem.tokenizeAny(u8, key_val.value, &.{';'});
        //TODO: not assume there is no "; ;; ;;;..." pattern when deciding size.
        self.categories = try .initCapacity(allocator, 2);
        var count: usize = 0;
        while (it.next()) |category| {
            if (category.len == 0) continue;
            try self.categories.?.append(allocator, try Utils.cloneString(category, allocator));
            count += 1;
        }
    }
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    if (self.command) |command| {
        allocator.free(command);
    }
    if (self.categories) |*categories| {
        for (categories.items) |category| {
            allocator.free(category);
        }
        categories.deinit(allocator);
    }
}

/// iterates over all .desktop files in dir and return an array
/// with all file names whose categories section contains category param.
pub fn getByCategory(category: []const u8, dir: std.Io.Dir, io: std.Io, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var it = dir.iterate();
    const buff = try allocator.alloc(u8, 4096);
    defer allocator.free(buff);
    var ret = std.ArrayList([]const u8);

    while (try it.next(io)) |entery| {
        if (entery.name.len >= 9 and Parse.endsWith(entery.name, ".desktop")) {
            const file = try dir.openFile(io, entery.name, .{});
            var reader = file.reader(io, buff);
            var info: Self = try Self.initParse(&reader.interface, allocator);
            defer info.deinit(allocator);
            if (info.categories) |categories| {
                for (categories.items) |cat| {
                    if (std.mem.eql(u8, cat, category)) {
                        ret.append(allocator, Utils.cloneString(entery.name, allocator));
                    }
                }
            }
        }
    }
    return ret;
}

test "init from file" {
    var buf: [4096]u8 = undefined;
    const file = try Utils.Test.openFile("Alacritty.desktop", .{});
    var reader = file.reader(std.testing.io, &buf);
    var desktop_file_info = try initParse(&reader.interface, std.testing.allocator);
    defer desktop_file_info.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep("alacritty", desktop_file_info.command.?);
}

//test "print categories" {
//    const folder = try std.Io.Dir.openDirAbsolute(std.testing.io, "/usr/share/applications", .{ .iterate = true });
//    const terminals = try getByCategory("TerminalEmulator", folder, std.testing.io, std.testing.allocator);
//}
