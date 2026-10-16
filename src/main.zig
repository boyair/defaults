pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena: std.mem.Allocator = init.arena.allocator();
    const config_dir = try utils.homeSubDir(init, ".config/");
    defer config_dir.close(io);
    const sdef_dir = try config_dir.createDirPathOpen(io, "sdef/", .{});
    defer sdef_dir.close(io);
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
        const defualts_file = sdef_dir.createFile(io, "defaults.csv", .{ .read = true, .truncate = false });
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
        _ = std.process.spawn(io, .{ .argv = &.{ "gio", "launch", command }, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore }) catch |err| {
            std.log.err("command \"{s}\" not found", .{command});
            return err;
        };
    } else if (res.args.set) |set| {
        //free precvious value
        apps.freeFieldByName(set, arena) catch |err| switch (err) {
            error.ItemMismatch => {
                std.log.err("{s} is not an app category.\ncheck -c to see available categories", .{set});
                return;
            },
            else => return err,
        };

        var reader = mime_info_file.reader(io, &buf);
        var items = try getAvailable(set, &reader.interface, applications_dir, io, arena);
        defer utils.destroyStringArray(&items, arena);
        try console_writer.interface.print("choose your default by entering a number {s}\n", .{set});
        try console_writer.interface.print("0. abort (dont change)\n", .{});
        for (items.items, 1..) |item, idx| {
            try console_writer.interface.print("{d}. {s}\n", .{ idx, item });
        }
        try console_writer.interface.print("your choice: ", .{});

        try console_writer.flush();
        const number = utils.getNumber(io) catch |err| switch (err) {
            error.ItemMismatch => {
                std.log.err("your input is not a number. aboting...", .{});
                return;
            },
            else => return err,
        };
        if (number < 0 or number > items.items.len) {
            std.log.err("this number is not an option. aborting...", .{});
            return;
        }
        if (number == 0) {
            try console_writer.interface.print("aborting...", .{});
            try console_writer.flush();
            return;
        }
        const chosen = items.items[@intCast(number - 1)];

        apps.setFieldByName(set, try utils.cloneString(chosen, arena)) catch |err| {
            std.log.err("expected App key, found {s}\n", .{set});
            return err;
        };
        mime_list_file = try config_dir.createFile(io, "mimeapps.list", .{});
        var writer = mime_list_file.writer(io, &buf);
        try MimeWrite.mimeWrite(&writer.interface, apps);
        try utils.updateConfig(apps, sdef_dir, io);
        std.log.info("set {s} to {s}", .{ set, chosen });
    } else if (res.args.log != 0) {
        try apps.print(&console_writer.interface, ':');
        try console_writer.flush();
    } else if (res.args.help != 0) {
        std.log.info("\n{s}\n", .{Help});
    } else if (res.args.available) |application| {
        var reader = mime_info_file.reader(io, &buf);
        var items = try getAvailable(application, &reader.interface, applications_dir, io, arena);
        defer utils.destroyStringArray(&items, arena);
        for (items.items) |item| {
            try console_writer.interface.print("app: {s}\n", .{item});
        }
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
        try utils.updateConfig(apps, sdef_dir, io);
    }
}

pub fn getAvailable(application: []const u8, mime_info_file: *std.Io.Reader, apps_dir: std.Io.Dir, io: std.Io, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    const relevant_category = try Parse.Fields.getFieldByNameRuntime(application, DefaultApps, &DefaultApps.MimeApps, ?[]const u8);

    const mime_info =
        if (relevant_category) |category| blk: {
            const mime_info = try Parse.Mime.findInFile(
                mime_info_file,
                try MimeInfo.Category.fromString(category),
                allocator,
            ) orelse return error.ItemNotFound;
            mime_info.category.deinit(allocator); // not needed for listing apps
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
    return mime_info;
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
    \\-s, --set <str>           sets default app in a category (-s browser).
    \\-c, --categories          list available app categories (browser, terminal, etc)
;

const params = clap.parseParamsComptime(Help);
