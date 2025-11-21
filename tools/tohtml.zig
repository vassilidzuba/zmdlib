const std = @import("std");
const zmdlib = @import("zmdlib");
const cli = @import("cli");

var config = struct {
    help: ?bool = false,
    event: ?bool = false,
    snippet: ?bool = false,
    output: ?[:0]const u8 = null,
    operands: std.ArrayList([:0]u8) = .empty,
}{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    defer {
        for (config.operands.items) |val| {
            allocator.free(val);
        }
        config.operands.deinit(allocator);
    }

    const command: cli.Command = .{
        .desc = "convert markdown to html",
        .options = &.{
            .{ .help = "display this help", .short_name = 'h', .long_name = "help", .ref = cli.ValueRef{ .boolean = &config.help } },
            .{ .help = "display events", .short_name = 'e', .long_name = "events", .ref = cli.ValueRef{ .boolean = &config.event } },
            .{ .help = "no html tag", .short_name = 's', .long_name = "snippet", .ref = cli.ValueRef{ .boolean = &config.snippet } },
            .{ .help = "output file", .short_name = 'o', .long_name = "output", .ref = cli.ValueRef{ .string = &config.output } },
        },
        .exec = runit,
        .operands = &config.operands,
    };

    try cli.parseCommandLine(allocator, &command, cli.ParserOpts{});

    if (config.help) |help| {
        if (help) {
            cli.printHelp(command);
            return;
        }
    }
}

fn runit(allocator: std.mem.Allocator) !void {
    if (config.event.?) {
        try runDisplayEvents(allocator);
    } else {
        try runConvert(allocator);
    }
}

fn runDisplayEvents(allocator: std.mem.Allocator) !void {
    for (config.operands.items) |path| {
        try zmdlib.displayEvents(allocator, path);
    }
}

fn runConvert(allocator: std.mem.Allocator) !void {
    for (config.operands.items) |path| {
        if (config.output) |output| {
            std.debug.print("Converting {s} !\n", .{path});
            std.debug.print("output file is {s} !\n\n\n", .{output});
            const file = try std.fs.cwd().createFile(
                output,
                .{ .read = true },
            );
            defer file.close();

            try zmdlib.md2htmlFile(allocator, path, file, .{ .snippet = config.snippet.? });
        } else {
            std.debug.print("Converting {s} !\n\n\n", .{path});
            try zmdlib.md2htmlFile(allocator, path, null, .{ .snippet = config.snippet.? });
        }
    }
}
