const std = @import("std");
const Parse = @import("parse.zig");
const Utils = @import("utils.zig");
const Self = @This();

is_application: bool = false,
//TODO: add is_hidden parameter back once i know the syntex and what it does.
//is_hidden: bool = false,
command: ?[]const u8 = null,
categories: ?[][]const u8 = null,

pub fn initParse(reader: *std.Io.Reader, allocator: std.mem.Allocator) !Self {
    var ret: Self = .{};
    while (try reader.takeDelimiter('\n')) |line| {
        //TODO: replace this line once i know what to do with a title
        if (std.mem.trim(u8, line, &.{ ' ', '\t' }).len == 0 or line[0] == '[') continue;
        try parseLine(line, allocator, &ret);
    }
    return ret;
}

fn parseLine(line: []const u8, allocator: std.mem.Allocator, self: *Self) !void {
    const trimmed = std.mem.trim(u8, line, &.{ ' ', '\t' });
    const eq_idx = std.mem.find(u8, trimmed, &.{'='}) orelse {
        std.log.err("failed to find a seperator\n", .{});
        return Parse.ParseError.TooFewItems;
    };
    const key = trimmed[0..eq_idx];
    const value = trimmed[eq_idx + 1 ..];
    if (std.mem.eql(u8, key, "Type")) {
        self.is_application = std.mem.eql(u8, value, "Application");
    } else if (self.command == null and std.mem.eql(u8, key, "Exec")) {
        self.command = try Utils.cloneString(value, allocator);
        std.debug.print("allocated: {s}\n", .{self.command.?});
    } else if (self.categories == null and std.mem.eql(u8, key, "Categories")) {
        var it = std.mem.tokenizeAny(u8, value, &.{';'});
        const category_count = std.mem.count(u8, value, &.{';'});
        //TODO: not assume there is no "; ;; ;;;..." pattern when deciding size.
        self.categories = try allocator.alloc([]const u8, category_count);
        var count: usize = 0;
        while (it.next()) |category| {
            if (category.len == 0) continue;
            self.categories.?[count] = try Utils.cloneString(category, allocator);
            count += 1;
        }
    }
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    if (self.command) |command| {
        allocator.free(command);
    }
    if (self.categories) |categories| {
        for (categories) |category| {
            allocator.free(category);
        }
        allocator.free(categories);
    }
}
test "init from file" {
    var buf: [4096]u8 = undefined;
    const file = try Utils.Test.openFile("Alacritty.desktop", .{});
    var reader = file.reader(std.testing.io, &buf);
    var desktop_file_info = try initParse(&reader.interface, std.testing.allocator);
    defer desktop_file_info.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep("alacritty", desktop_file_info.command.?);
}
