pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena: std.mem.Allocator = init.arena.allocator();
    const config_dir = try utils.homeSubDir(init, ".config/sdef");
    defer config_dir.close(io);
    const applications_dir = try utils.globalApplocationsDir(init);

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
        };
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
        const mime_file = try applications_dir.openFile(io, "mimeinfo.cache", .{});
        var reader = mime_file.reader(io, &buf);
        const relevant_category = try Parse.Fields.getFieldByNameRuntime(application, DefaultApps, &DefaultApps.mimeApps, ?[]const u8);
        if (relevant_category) |category| {
            const mime_info = try Parse.Mime.findInFile(&reader.interface, try MimeInfo.Category.fromString(category), arena) orelse {
                std.log.err("no applications of kind '{s}' are available\n", .{application});
                return;
            };
            for (mime_info.apps.items) |app| {
                try console_writer.interface.print("app: {s}\n", .{app});
            }
            try console_writer.flush();
        } else {
            std.log.err("requested category {s} does not support search yet. please search manually", .{application});
            return;
        }
    } else {
        try utils.updateConfig(apps, config_dir, io);
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
