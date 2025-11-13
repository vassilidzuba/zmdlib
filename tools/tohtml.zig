const std = @import("std");
const zmdlib = @import("zmdlib");
const cli = @import("cli");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var config = struct {
        help: ?bool = false,
        operands: std.ArrayList([:0]u8) = .empty,
    }{};
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
        },
        .operands = &config.operands,
    };

    try cli.parseCommandLine(allocator, &command, cli.ParserOpts{});

    if (config.help) |help| {
        if (help) {
            cli.printHelp(command);
            return;
        }
    }

    for (config.operands.items) |path| {
        std.debug.print("Converting {s} !\n\n\n", .{path});
        try zmdlib.md2htmlFile(allocator, path);
    }
}
