pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena: std.mem.Allocator = init.arena;
    const config_dir = try utils.homeSubDir(init, ".config/");
    defer config_dir.close(io);
    const applications_dir = try utils.globalApplocationsDir(init);
    const mime_info_file = try applications_dir.openFile(io, "mimeinfo.cache", .{});
    var mime_list_file: std.Io.File = undefined;
    var buf: [4096]u8 = undefined; //buffer used for reading files throughout the program

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, Parse.Clap.Parsers, init.minimal.args, .{ .diagnostic = &diag, .allocator = init.gpa }) catch |err| {
        std.log.err("incorrect input. try 'defaults -h' for help", .{});
        try diag.reportToFile(init.io, .stderr(), err);
        return;
    };
    defer res.deinit();

    var apps: DefaultApps = blk: {
        const defualts_file = config_dir.openFile(io, "sdef/defaults.csv", .{}) catch |err|
            switch (err) {
                error.FileNotFound => try config_dir.createFile(io, "sdef/defaults.csv", .{ .read = true }),
                else => {
                    std.log.err("failed to open config file", .{});
                    return err;
                },
            };
        defer defualts_file.close(io);
        var reader = defualts_file.reader(io, &buf);
        break :blk try DefaultApps.initParse(&reader.interface, arena);
    };

    defer apps.deinit(arena);
    var console_writer = Io.File.stdout().writer(io, &buf);

    if (res.args.run) |run| {
        const app = apps.getFieldByName(run) catch |err| {
            std.log.err("expected App class, found {s}\n", .{run});
            return err;
        } orelse return error.ItemNotFound;
        const command = try std.fs.path.join(arena, &.{ utils.ApplicationPath, app });
        defer arena.free(command);
        std.debug.print("command: {s}\n", .{command});
        _ = std.process.spawn(io, .{ .argv = &.{ "gio", "launch", command }, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore }) catch |err| {
            std.log.err("command \"{s}\" not found", .{command});
            return err;
        };
    } else if (res.args.set) |set| {
        //free precvious value
        try apps.freeFieldByName(set.key, arena);

        apps.setFieldByName(set.key, try utils.cloneString(set.value, arena)) catch |err| {
            std.log.err("expected App key, found {s}\n", .{set.key});
            return err;
        };
        mime_list_file = try config_dir.createFile(io, "mimeapps.list", .{});
        var writer = mime_list_file.writer(io, &buf);
        try MimeWrite.mimeWrite(&writer.interface, apps);
        try utils.updateConfig(apps, config_dir, io);
        std.log.info("set {s} to {s}", set);
    } else if (res.args.log != 0) {
        try apps.print(&console_writer.interface, ':');
        try console_writer.flush();
    } else if (res.args.help != 0) {
        std.log.info("\n{s}\n", .{Help});
    } else if (res.args.available) |application| {
        var reader = mime_info_file.reader(io, &buf);
        try listAvailable(application, &reader.interface, applications_dir, io, &console_writer.interface, arena);
        try console_writer.flush();
    } else if (res.args.categories != 0) {
        inline for (@typeInfo(DefaultApps).@"struct".fields) |field| {
            try console_writer.interface.print("{s}\n", .{field.name});
        }
        try console_writer.flush();
    } else {
        mime_list_file = try config_dir.createFile(io, "mimeapps.list", .{});
        var writer = mime_list_file.writer(io, &buf);
        try MimeWrite.mimeWrite(&writer.interface, apps);
        try utils.updateConfig(apps, config_dir, io);
    }
}

pub fn listAvailable(application: []const u8, mime_info_file: *std.Io.Reader, apps_dir: std.Io.Dir, io: std.Io, out: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    const relevant_category = try Parse.Fields.getFieldByNameRuntime(application, DefaultApps, &DefaultApps.MimeApps, ?[]const u8);

    var mime_info =
        if (relevant_category) |category| blk: {
            const mime_info = try Parse.Mime.findInFile(
                mime_info_file,
                try MimeInfo.Category.fromString(category),
                allocator,
            ) orelse return error.ItemNotFound;
            mime_info.category.deinit(allocator);
            break :blk mime_info.apps;
        } else blk: {
            const category = try Parse.Fields.getFieldByNameRuntime(
                application,
                DefaultApps,
                &DefaultApps.MimeAppCategories,
                ?[]const u8,
            );
            break :blk try desktopFileInfo.getByCategory(category orelse return error.ItemNotFound, apps_dir, io, allocator);
        };
    defer utils.destroyStringArray(&mime_info, allocator);

    for (mime_info.items) |app| {
        try out.print("{s}\n", .{app});
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
const MimeWrite = @import("mimeAppsWrite.zig");
const Help: []const u8 =
    \\-h, --help                Display this help and exit.
    \\-l, --log                 Display active config.
    \\-a, --available <str>     Lists available applications.
    \\-r, --run <str>           runs the chosen default app.
    \\-s, --set <set>           sets default app (for example browser=firefox).
    \\-c, --categories          list available app categories (browser, terminal, etc)
;

const params = clap.parseParamsComptime(Help);
