/// ustilitiez used for text parsing within the program.
const std = @import("std");
const MimeInfo = @import("mimeInfo.zig");
const clap = @import("clap");
const Utils = @import("utils.zig");

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

pub fn splitToArr(string: []const u8, delimiters: []const u8, allocator: std.mem.Allocator) error{OutOfMemory}!std.ArrayList([]const u8) {
    var ret = try std.ArrayList([]const u8).initCapacity(allocator, 2);
    var it = std.mem.tokenizeAny(u8, string, delimiters);
    while (it.next()) |token| {
        const trimmed = trim(token);
        if (trimmed.len == 0) continue;
        try ret.append(allocator, try Utils.cloneString(trimmed, allocator));
    }
    return ret;
}

pub const Mime = struct {
    pub fn findInFile(reader: *std.Io.Reader, category: MimeInfo.Category, allocator: std.mem.Allocator) (ParseError || error{ OutOfMemory, ReadFailed, StreamTooLong })!?MimeInfo {
        while (try reader.takeDelimiter('\n')) |line| {
            //TODO: replace this line once i know what to do with a title
            if (line[0] == '[' or line[0] == '#') continue;
            var info = try MimeInfo.initParse(line, allocator);
            if (std.mem.eql(u8, info.category.top, category.top) and std.mem.eql(u8, info.category.sub, category.sub)) {
                return info;
            } else {
                info.deinit(allocator);
                continue;
            }
        }
        return null;
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

test "mime file parse" {
    //reading line 245 in test mime file
    const io = std.testing.io;
    const file = try std.Io.Dir.cwd().openFile(io, "test/mime.cache", .{});
    const buffer: []u8 = try std.testing.allocator.alloc(u8, 4096);
    defer std.testing.allocator.free(buffer);
    var reader = file.reader(io, buffer);
    var result = try Mime.findInFile(&reader.interface, .{ .top = "image", .sub = "png" }, std.testing.allocator) orelse {
        std.log.err("could nit find requested category {s}, {s}\n", .{ .top = "image", .sub = "png" });
        return ParseError.ItemMismatch;
    };
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep("com.interversehq.qView.desktop", result.apps.items[0]);
    try std.testing.expectEqualDeep("com.system76.CosmicViewer.desktop", result.apps.items[1]);
}
test "split to array" {
    const string = ",,banana , , ,\t ,apple, ,,orange";
    var arr = try splitToArr(string, &.{','}, std.testing.allocator);
    defer Utils.destroyStringArray(&arr, std.testing.allocator);

    try std.testing.expectEqual(3, arr.items.len);
    try std.testing.expectEqualDeep("banana", arr.items[0]);
    try std.testing.expectEqualDeep("apple", arr.items[1]);
    try std.testing.expectEqualDeep("orange", arr.items[2]);
}
