///struct for storing info about mime
category: Category,
apps: std.ArrayList([]const u8),
pub fn initParse(string: []const u8, allocator: std.mem.Allocator) (Parse.ParseError || error{OutOfMemory})!Self {
    const line_to_use = Parse.trim(string);

    var ret: Self = undefined;
    const key_val = try Parse.KeyValuePair.init(line_to_use);
    //parse category
    {
        const category = key_val.key;
        const slash_idx = std.mem.find(u8, category, &.{'/'}) orelse {
            std.log.err("failed to find a seperator\n", .{});
            return Parse.ParseError.TooFewItems;
        };
        const top = category[0..slash_idx];
        const sub = category[slash_idx + 1 ..];

        ret.category.top = try Utils.cloneString(top, allocator);
        ret.category.sub = try Utils.cloneString(sub, allocator);
    }

    //parse apps
    {
        const apps = key_val.value;
        ret.apps = try Parse.splitToArr(apps, &.{';'}, allocator);
    }

    return ret;
}

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
    pub fn deinit(self: Category, allocator: std.mem.Allocator) void {
        allocator.free(self.top);
        allocator.free(self.sub);
    }
};

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    Utils.destroyStringArray(&self.apps, allocator);
    self.category.deinit(allocator);
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

test "init parse" {
    var info = try initParse("audio/x-mp3=audacious.desktop;;", std.testing.allocator);
    defer info.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep("audio", info.category.top);
    try std.testing.expectEqualDeep("x-mp3", info.category.sub);
    try std.testing.expectEqualDeep("audacious.desktop", info.apps.items[0]);
    var allocated_info = try initParse("text/x-c++hdr=micro.desktop;nvim.desktop;vim.desktop;", std.testing.allocator);
    defer allocated_info.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep("text", allocated_info.category.top);
    try std.testing.expectEqualDeep("x-c++hdr", allocated_info.category.sub);
    try std.testing.expectEqualDeep("micro.desktop", allocated_info.apps.items[0]);
    try std.testing.expectEqualDeep("nvim.desktop", allocated_info.apps.items[1]);
    try std.testing.expectEqualDeep("vim.desktop", allocated_info.apps.items[2]);
}
const Self = @This();
const std = @import("std");
const Parse = @import("parse.zig");
const Utils = @import("utils.zig");
