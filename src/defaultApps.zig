browser: ?[]const u8 = null,
terminal: ?[]const u8 = null,
@"file-manager": ?[]const u8 = null,
@"text-editor": ?[]const u8 = null,
@"video-player": ?[]const u8 = null,
@"image-viewer": ?[]const u8 = null,

/// recives config file content as a string.
/// parses it to initiallize a struct.
/// returns initiallized struct.
/// can fail when file content is invalid.
pub fn initParse(file: []const u8, allocator: std.mem.Allocator) parse.ParseError!Self {
    var ret: Self = .{};
    var line_reader = std.mem.splitScalar(u8, file, '\n');
    var line_number: usize = 1;
    while (line_reader.next()) |line| {
        if (std.mem.trim(u8, line, &.{ ' ', '\t' }).len == 0) continue; //ignore empty or whitespaces lines
        const result = parseLine(line, allocator) catch |err| {
            std.log.err("failed to read line: {d}\n", .{line_number});
            return err;
        };
        defer allocator.free(result.class);
        if (!StructFieldParser.setFieldByNameRuntime(result.class, Self, &ret, result.name)) {
            std.log.err("failed to read line: {d}\n", .{line_number});
            return parse.ParseError.ItemMismatch;
        }
        line_number += 1;
    }
    return ret;
}
pub fn getFieldByName(self: *const Self, field: []const u8) parse.ParseError![]const u8 {
    return parse.Fields.getFieldByNameRuntime(field, Self, self, []const u8);
}

pub fn setFieldByName(self: *Self, field: []const u8, value: []const u8) parse.ParseError!void {
    if (!parse.Fields.setFieldByNameRuntime(field, Self, self, value)) return parse.ParseError.ItemMismatch;
}

pub fn print(self: *const Self, writer: *std.Io.Writer, seperator: u8) !void {
    inline for (std.meta.fields(Self)) |field| {
        if (@field(self.*, field.name)) |val| {
            try writer.print("{s}{c} {s}\n", .{ field.name, seperator, val });
        }
    }
}

/// takes a string and checks whether or not
/// it is a class name.
/// returns boolean indicator.
fn isValidClass(class: []const u8) bool {
    for (std.meta.fieldNames(Self)) |cls| {
        if (std.mem.eql(u8, class, cls)) {
            return true;
        }
    }
    return false;
}

// recives a line of a csv as a string.
// returns a struct containing the class and name parsed from the line.
// can fail when line is invalid.
fn parseLine(line: []const u8, allocator: std.mem.Allocator) parse.ParseError!AppInfo {
    var ret: AppInfo = undefined;
    var split = std.mem.splitScalar(u8, line, ',');

    // get class string
    if (split.next()) |class| {
        const trimmed = std.mem.trim(u8, class, &.{' '});
        ret.class = allocator.alloc(u8, trimmed.len) catch unreachable;
        @memcpy(ret.class, trimmed);
    } else {
        return parse.ParseError.TooFewItems;
    }

    // get name string
    if (split.next()) |name| {
        const trimmed = std.mem.trim(u8, name, &.{' '});
        ret.name = allocator.alloc(u8, trimmed.len) catch unreachable;
        @memcpy(ret.name, trimmed);
    } else {
        return parse.ParseError.TooFewItems;
    }

    return ret;
}

fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    inline for (std.meta.fields(@TypeOf(self.*))) |field| {
        const val = @field(self.*, field.name);
        if (val) |str| {
            std.debug.print("freed: {s}\n", .{str});
            allocator.free(str);
        }
    }
}

const AppInfo = struct {
    class: []u8,
    name: []u8,
};

const StructFieldParser = @import("parse.zig").Fields;

// TESTS
test "init" {
    var apps = try Self.initParse(
        \\file-manager, nemo
        \\terminal, ghostty
        \\browser, firefox
    , std.testing.allocator);
    defer apps.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep("nemo", apps.@"file-manager".?);
    try std.testing.expectEqualDeep("ghostty", apps.terminal.?);
    try std.testing.expectEqualDeep("firefox", apps.browser.?);
}

/// categories to look for when searching the current default mime app.
pub const mimeApps: Self = .{
    .browser = "x-scheme-handler/https",
    .@"image-viewer" = "image/png",
    .@"video-player" = "video/mp4",
    .@"text-editor" = "text/plain",
    .terminal = "application/x-terminal-emulator",
};

const std = @import("std");
const Self = @This();
const parse = @import("parse.zig");
