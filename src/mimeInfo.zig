///struct for storing info about mime
const Self = @This();
const std = @import("std");
const Parse = @import("parse.zig");
category: Category,
apps: [][]const u8,
original_line: ?[]const u8,

pub const Category = struct {
    top: []const u8,
    sub: []const u8,
    pub fn toString(self: Category, allocator: std.mem.Allocator) error{OutOfMemory}![]u8 {
        const string_size = self.top.len + self.sub.len + 1;
        const ret = try allocator.alloc(u8, string_size);
        @memcpy(ret[0..self.top.len], self.top);
        ret[self.top.len] = '/';
        @memcpy(ret[self.top.len + 1 ..], self.sub);
        return ret;
    }
    pub fn fromString(string: []const u8) Parse.ParseError!Category {
        const slash_idx = std.mem.find(u8, string, &.{'/'}) orelse {
            std.log.err("failed to find a seperator\n", .{});
            return Parse.ParseError.TooFewItems;
        };
        const top = string[0..slash_idx];
        const sub = string[slash_idx + 1 ..];
        return .{ .top = top, .sub = sub };
    }
};

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    allocator.free(self.apps);
    if (self.original_line) |line| {
        allocator.free(line);
    }
}

test "category to string" {
    const category1: Category = .{ .top = "image", .sub = "png" };
    const string1 = try category1.toString(std.testing.allocator);
    defer std.testing.allocator.free(string1);
    try std.testing.expectEqualDeep("image/png", string1);
    const category2: Category = .{ .top = "", .sub = "" };
    const string2 = try category2.toString(std.testing.allocator);
    defer std.testing.allocator.free(string2);
    try std.testing.expectEqualDeep("/", string2);
}

test "category from string" {
    const string1 = "image/png";
    const category1 = try Category.fromString(string1);
    try std.testing.expectEqualDeep("image", category1.top);
    try std.testing.expectEqualDeep("png", category1.sub);
    const string2 = "/";
    const category2 = try Category.fromString(string2);
    try std.testing.expectEqualDeep("", category2.top);
    try std.testing.expectEqualDeep("", category2.sub);
}
