pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena: std.mem.Allocator = init.arena.allocator();
    const config_dir = try utils.homeSubDir(init, ".config/sdef");
    defer config_dir.close(io);
    const applications_dir = try utils.globalApplocationsDir(init);
    const mime_file = try applications_dir.openFile(io, "mimeinfo.cache", .{});

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, Parse.Clap.Parsers, init.minimal.args, .{ .diagnostic = &diag, .allocator = init.gpa }) catch |err| {
        try diag.reportToFile(init.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    var apps = try DefaultApps.initParse(try config_dir.readFileAlloc(io, "defaults.csv", arena, .unlimited), arena);

    var buf: [4096]u8 = undefined; //buffer used for reading files throughout the program
    var console_writer = Io.File.stdout().writer(io, &buf);

    if (res.args.run) |run| {
        const app = apps.getFieldByName(run) catch |err| {
            std.log.err("expected App class, found {s}\n", .{run});
            return err;
        } orelse return error.ItemNotFound;
        const command = try std.fs.path.join(arena, &.{ utils.ApplicationPath, app });
        std.debug.print("command: {s}\n", .{command});
        _ = std.process.spawn(io, .{ .argv = &.{ "gio", "launch", command }, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore }) catch |err| {
            std.log.err("command \"{s}\" not found", .{command});
            return err;
        };
    } else if (res.args.set) |set| {
        apps.setFieldByName(set.key, set.value) catch |err| {
            std.log.err("expected App key, found {s}\n", .{set.key});
            return err;
        };
        try utils.updateConfig(apps, config_dir, io);
        std.log.info("set {s} to {s}", set);
    } else if (res.args.log != 0) {
        try apps.print(&console_writer.interface, ':');
        try console_writer.flush();
    } else if (res.args.help != 0) {
        std.log.info("\n{s}\n", .{Help});
    } else if (res.args.@"list-available") |application| {
        var reader = mime_file.reader(io, &buf);
        try listAvailable(application, &reader.interface, applications_dir, io, &console_writer.interface, arena);
        try console_writer.flush();
    } else {
        try utils.updateConfig(apps, config_dir, io);
    }
}

pub fn listAvailable(application: []const u8, mime_info_file: *std.Io.Reader, apps_dir: std.Io.Dir, io: std.Io, out: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    const relevant_category = try Parse.Fields.getFieldByNameRuntime(application, DefaultApps, &DefaultApps.mimeApps, ?[]const u8);

    const mime_info =
        if (relevant_category) |category|
            (try Parse.Mime.findInFile(
                mime_info_file,
                try MimeInfo.Category.fromString(category),
                allocator,
            ) orelse return error.ItemNotFound).apps
        else
            try desktopFileInfo.getByCategory("TerminalEmulator", apps_dir, io, allocator);

    for (mime_info.items) |app| {
        try out.print("app: {s}\n", .{app});
    }
}
const std = @import("std");
const Io = std.Io;
const DefaultApps = @import("defaultApps.zig");
const clap = @import("clap");
const utils = @import("utils.zig");
const Parse = @import("parse.zig");
const MimeInfo = @import("mimeInfo.zig");
const desktopFileInfo = @import("desktopFileInfo.zig");
const Help: []const u8 =
    \\-h, --help                Display this help and exit.
    \\-l, --log                 Display active config.
    \\--list-available <str>    Lists available applications.
    \\-r, --run <str>           runs the chosen default app.
    \\-s, --set <set>           sets default app (for example browser=firefox).
;

const params = clap.parseParamsComptime(Help);
