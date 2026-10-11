const std = @import("std");
const DefaultApps = @import("defaultApps.zig");
const Utils = @import("utils.zig");

pub const categories = DefaultApps.customTypeData([]const []const u8){
    .browser = &.{
        "text/html",
        "x-scheme-handler/http",
        "x-scheme-handler/https",
        "x-scheme-handler/about",
        "x-scheme-handler/unknown",
    },
    .terminal = &.{
        "application/x-terminal-emulator",
        "x-scheme-handler/terminal",
    },
    .@"file-manager" = &.{
        "inode/directory",
    },
    .@"text-editor" = &.{
        "text/plain",
    },
    .@"video-player" = &.{
        "video/3gp",
        "video/3gpp",
        "video/3gpp2",
        "video/divx",
        "video/dv",
        "video/fli",
        "video/flv",
        "video/mp2t",
        "video/mp4",
        "video/mp4v-es",
        "video/mpeg",
        "video/mpeg-system",
        "video/msvideo",
        "video/ogg",
        "video/quicktime",
        "video/vivo",
        "video/vnd.divx",
        "video/vnd.mpegurl",
        "video/vnd.rn-realvideo",
        "video/vnd.vivo",
        "video/webm",
        "video/x-anim",
        "video/x-avi",
        "video/x-flc",
        "video/x-fli",
        "video/x-flic",
        "video/x-flv",
        "video/x-m4v",
        "video/x-matroska",
        "video/x-mjpeg",
        "video/x-mpeg",
        "video/x-mpeg2",
        "video/x-ms-asf",
        "video/x-ms-asf-plugin",
        "video/x-ms-asx",
        "video/x-ms-wm",
        "video/x-ms-wmv",
        "video/x-ms-wmx",
        "video/x-ms-wvx",
        "video/x-msvideo",
        "video/x-nsv",
        "video/x-ogm+ogg",
        "video/x-theora",
        "video/x-theora+ogg",
        "video/x-totem-stream",
    },
    //TODO: fill these with the relevant mime categories
    .@"image-viewer" = &.{},
    .@"pdf-viewer" = &.{},
};

pub fn mimeWrite(writer: *std.Io.Writer, apps: DefaultApps) !void {
    try writer.print("[Default Applications]\n", .{});
    inline for (std.meta.fields(@TypeOf(categories))) |category| {
        const list = @field(categories, category.name);
        const maybe_app = @field(apps, category.name);
        if (maybe_app) |app| {
            for (list) |string| {
                try writer.print("{s}={s};\n", .{ string, app });
            }
        }
    }
    try writer.flush();
}
//TODO: make this an actual test
test "mime write" {
    const buf = try std.testing.allocator.alloc(u8, 4096);
    defer std.testing.allocator.free(buf);
    const dir = try std.Io.Dir.cwd().openDir(std.testing.io, "test", .{});
    const file = try dir.createFile(std.testing.io, "mimeapps.list", .{});
    var writer = file.writer(std.testing.io, buf);
    try mimeWrite(&writer.interface, .{ .browser = "helium.desktop", .terminal = "com.mitchellh.ghostty.desktop" });
}
