/// ustilitiez used for text parsing within the program.
const std = @import("std");
const MimeInfo = @import("mimeInfo.zig");
const clap = @import("clap");

pub fn endsWith(string: []const u8, end: []const u8) bool {
    if (end.len > string.len)
        return false;
    if (end.len == 0)
        return true;
    return std.mem.eql(u8, string[string.len - end.len ..], end);
}

/// trims whitspaces
pub fn trim(string: []const u8) []const u8 {
    return std.mem.trim(u8, string, &.{ ' ', '\t' });
}
pub const Mime = struct {
    pub fn findInFile(reader: *std.Io.Reader, category: MimeInfo.Category, allocator: std.mem.Allocator) (ParseError || error{ OutOfMemory, ReadFailed, StreamTooLong })!?MimeInfo {
        while (try reader.takeDelimiter('\n')) |line| {
            //TODO: replace this line once i know what to do with a title
            if (line[0] == '[' or line[0] == '#') continue;
            const info = try parseLine(line, allocator, true);
            if (std.mem.eql(u8, info.category.top, category.top) and std.mem.eql(u8, info.category.sub, category.sub)) {
                return info;
            } else {
                info.deinit(allocator);
                continue;
            }
        }
        return null;
    }
    pub fn parseLine(line: []const u8, allocator: std.mem.Allocator, clone_string: bool) (ParseError || error{OutOfMemory})!MimeInfo {
        const line_to_use = if (clone_string) try allocator.dupe(u8, line) else line;

        const trimmed = trim(line);
        const eq_idx = std.mem.find(u8, trimmed, &.{'='}) orelse {
            std.log.err("failed to find a seperator\n", .{});
            return ParseError.TooFewItems;
        };

        var ret: MimeInfo = .{ .original_line = if (clone_string) line_to_use else null, .apps = undefined, .category = undefined };
        //parse category
        {
            const category = trimmed[0..eq_idx];
            const slash_idx = std.mem.find(u8, category, &.{'/'}) orelse {
                std.log.err("failed to find a seperator\n", .{});
                return ParseError.TooFewItems;
            };
            const top = category[0..slash_idx];
            const sub = category[slash_idx + 1 ..];

            ret.category.top = top;
            ret.category.sub = sub;
        }

        //parse apps
        {
            const apps = trimmed[eq_idx + 1 ..];
            const app_count = std.mem.count(u8, apps, &.{';'});
            ret.apps = try allocator.alloc([]const u8, app_count);

            var idx: usize = 0;
            var tokens = std.mem.tokenizeAny(u8, apps, &.{';'});
            while (tokens.next()) |token| {
                if (token.len > 0) {
                    ret.apps[idx] = token;
                }
                idx += 1;
            }
        }

        return ret;
    }
};

pub const Fields = struct {
    /// takes a struct type, a pointer to an instance,
    /// a (runtime known) field name and a value.
    /// sets the the appropriate field to the given value.
    /// expects cleaned version of field name (spaces instean of underscores)
    pub fn setFieldByNameRuntime(field: []const u8, strct: type, strct_ptr: *strct, value: anytype) bool {
        inline for (std.meta.fields(strct)) |fld| {
            if (std.mem.eql(u8, field, fld.name)) {
                @field(strct_ptr.*, fld.name) = value;
                return true;
            }
        }
        return false;
    }

    pub fn getFieldByNameRuntime(field: []const u8, strct: type, strct_ptr: *const strct, field_type: type) ParseError!field_type {
        inline for (std.meta.fields(strct)) |fld| {
            if (std.mem.eql(u8, field, fld.name)) {
                return @field(strct_ptr.*, fld.name).?;
            }
        }
        return ParseError.ItemMismatch;
    }
};

pub const KeyValuePair = struct {
    const Self = @This();
    key: []const u8,
    value: []const u8,

    pub fn init(string: []const u8) ParseError!Self {
        const idx = std.mem.indexOf(u8, string, &.{'='}) orelse return ParseError.TooFewItems;
        return .{ .key = string[0..idx], .value = string[idx + 1 ..] };
    }
};
/// Parse KEY=VALUE pairs
pub const ParseError = error{
    TooManyItems,
    TooFewItems,
    EmptyItem,
    ItemMismatch,
};

pub const Clap = struct {
    /// struct used to parse KEY=VALUE pairs
    pub const Parsers = .{ .str = clap.parsers.string, .set = KeyValuePair.init };
};
test "mime line parse" {
    const info = try Mime.parseLine("audio/x-mp3=audacious.desktop;;", std.testing.allocator, false);
    defer info.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep("audio", info.category.top);
    try std.testing.expectEqualDeep("x-mp3", info.category.sub);
    try std.testing.expectEqualDeep("audacious.desktop", info.apps[0]);
    const allocated_info = try Mime.parseLine("text/x-c++hdr=micro.desktop;nvim.desktop;vim.desktop;", std.testing.allocator, true);
    defer allocated_info.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep("text", allocated_info.category.top);
    try std.testing.expectEqualDeep("x-c++hdr", allocated_info.category.sub);
    try std.testing.expectEqualDeep("micro.desktop", allocated_info.apps[0]);
    try std.testing.expectEqualDeep("nvim.desktop", allocated_info.apps[1]);
    try std.testing.expectEqualDeep("vim.desktop", allocated_info.apps[2]);
}

test "mime file parse" {
    //reading line 245 in test mime file
    const io = std.testing.io;
    const file = try std.Io.Dir.cwd().openFile(io, "test/mime.cache", .{});
    const buffer: []u8 = try std.testing.allocator.alloc(u8, 4096);
    defer std.testing.allocator.free(buffer);
    var reader = file.reader(io, buffer);
    const result = try Mime.findInFile(&reader.interface, .{ .top = "image", .sub = "png" }, std.testing.allocator) orelse {
        std.log.err("could nit find requested category {s}, {s}\n", .{ .top = "image", .sub = "png" });
        return ParseError.ItemMismatch;
    };
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep("com.interversehq.qView.desktop", result.apps[0]);
    try std.testing.expectEqualDeep("com.system76.CosmicViewer.desktop", result.apps[1]);
}
