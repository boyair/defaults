browser: ?[]const u8 = null,
terminal: ?[]const u8 = null,
@"file-manager": ?[]const u8 = null,
@"text-editor": ?[]const u8 = null,
@"video-player": ?[]const u8 = null,
@"image-viewer": ?[]const u8 = null,
@"pdf-viewer": ?[]const u8 = null,

/// generates a new struct with the same field names as DefaultApps
/// but with a custom type instead of the default ?[]const u8.
///
/// does not share the same custom functions with DeafaultApps.
pub fn customTypeData(field_type: type) type {
    const fieldNames = std.meta.fieldNames(Self);
    const ret = @Struct(.auto, null, fieldNames, &@splat(field_type), &@splat(.{}));
    return ret;
}

/// recives config file content as a string.
/// parses it to initiallize a struct.
/// returns initiallized struct.
/// can fail when file content is invalid.
pub fn initParse(file: *std.Io.Reader, allocator: std.mem.Allocator) (error{OutOfMemory} || std.Io.Reader.DelimiterError || Parse.ParseError)!Self {
    var ret: Self = .{};
    var line_number: usize = 1;
    while (try file.takeDelimiter('\n')) |line| {
        var result = Parse.CSV.parseLine(line, allocator) catch |err| {
            std.log.err("failed to read line: {d}\n", .{line_number});
            return err;
        };
        defer Utils.destroyStringArray(&result, allocator);
        if (!StructFieldParser.setFieldByNameRuntime(result.items[0], Self, &ret, try Utils.cloneString(result.items[1], allocator))) {
            std.log.err("failed to read line: {d}\n", .{line_number});
            return Parse.ParseError.ItemMismatch;
        }
        line_number += 1;
    }
    return ret;
}

pub fn getFieldByName(self: *const Self, field: []const u8) Parse.ParseError!?[]const u8 {
    return Parse.Fields.getFieldByNameRuntime(field, Self, self, ?[]const u8);
}

pub fn freeFieldByName(self: *Self, field: []const u8, allocator: std.mem.Allocator) Parse.ParseError!void {
    if (try Parse.Fields.getFieldByNameRuntime(field, Self, self, ?[]const u8)) |val| {
        allocator.free(val);
    }
    try self.setFieldByName(field, null);
}

pub fn setFieldByName(self: *Self, field: []const u8, value: ?[]const u8) Parse.ParseError!void {
    if (!Parse.Fields.setFieldByNameRuntime(field, Self, self, value)) return Parse.ParseError.ItemMismatch;
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

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    inline for (std.meta.fields(@TypeOf(self.*))) |field| {
        const val = @field(self.*, field.name);
        if (val) |str| {
            std.debug.print("freed : {s}\n", .{field.name});
            allocator.free(str);
        }
    }
}

const StructFieldParser = @import("parse.zig").Fields;

// TESTS
test "init" {
    var reader = std.Io.Reader.fixed(
        \\browser, firefox.desktop
        \\terminal, Alacritty.desktop
        \\file-manager, com.system76.CosmicFiles.desktop
        \\text-editor, com.system76.CosmicEdit.desktop
        \\video-player, com.system76.CosmicPlayer.desktop
        \\image-viewer, com.interversehq.qView.desktop
        \\pdf-viewer, asdas
    );
    var apps = try Self.initParse(&reader, std.testing.allocator);
    defer apps.deinit(std.testing.allocator);
    //   try std.testing.expectEqualDeep("nemo", apps.@"file-manager".?);
    //   try std.testing.expectEqualDeep("ghostty", apps.terminal.?);
    //   try std.testing.expectEqualDeep("firefox", apps.browser.?);
}

/// categories to look for when searching the current default mime app.
pub const MimeAppCategories = Self{
    .browser = "WebBrowser",
    .terminal = "TerminalEmulator",
    .@"file-manager" = "FileManager",
    .@"text-editor" = "TextEditor",
};
pub const MimeApps: Self = .{
    .browser = "x-scheme-handler/https",
    .@"image-viewer" = "image/png",
    .@"video-player" = "video/mp4",
    .@"text-editor" = "text/plain",
    .@"file-manager" = "inode/directory",
    .@"pdf-viewer" = "application/pdf",
};
const std = @import("std");
const Self = @This();
const Parse = @import("parse.zig");
const Utils = @import("utils.zig");

//const getString()
//@typeInfo(ApplicationTypes).@"enum".fields
