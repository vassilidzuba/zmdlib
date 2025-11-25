const std = @import("std");
const cli = @import("cli");
const httpz = @import("httpz");
const zmdlib = @import("zmdlib");

var config = struct {
    help: ?bool = false,
    port: ?[:0]const u8 = null,
}{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const command: cli.Command = .{
        .desc = "server converting markdown to html",
        .options = &.{
            .{ .help = "display this help", .short_name = 'h', .long_name = "help", .ref = cli.ValueRef{ .boolean = &config.help } },
            .{ .help = "port number", .short_name = 'p', .long_name = "port", .ref = cli.ValueRef{ .string = &config.port } },
        },
        .exec = runserver,
    };

    try cli.parseCommandLine(allocator, &command, cli.ParserOpts{});

    if (config.help) |help| {
        if (help) {
            cli.printHelp(command);
            return;
        }
    }
}

fn runserver(allocator: std.mem.Allocator) !void {
    const port = try getPort();
    std.debug.print("starting to wait for requests on port {d}\n", .{port});

    var server = try httpz.Server(void).init(allocator, .{ .port = port }, {});
    defer {
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});
    router.post("/tohtml", toHtml, .{});

    // blocks
    try server.listen();
}

fn getPort() !u16 {
    if (config.port) |port| {
        return try std.fmt.parseInt(u16, port, 10);
    } else {
        return 8080;
    }
}

fn toHtml(req: *httpz.Request, res: *httpz.Response) !void {
    // TODO/ shout be improved to allow some parralelism!!!
    const tempfilename = "/tmp/tohtmlsrv.md";

    if (req.body()) |body| {
        std.debug.print("received request ({d} bytes)\n", .{body.len});
        if (req.header("content-type")) |ct| {
            if (!std.mem.eql(u8, ct, "text/markdown")) {
                res.status = 400;
                res.body = "error: content-type should be text/markdown\n";
                return;
            }
        }

        res.status = 200;

        const file = try std.fs.cwd().createFile(
            tempfilename,
            .{ .read = true },
        );
        defer file.close();

        try zmdlib.md2htmlText(res.arena, req.body().?, file, .{ .snippet = true });

        const file2 = try std.fs.openFileAbsolute(tempfilename, .{});
        defer file2.close();

        const file_size = try file2.getEndPos();
        const buffer = try res.arena.alloc(u8, file_size);

        _ = try file2.readAll(buffer);

        //    res.body = try std.fmt.allocPrint(res.arena, "{s}", .{buffer});
        res.body = buffer;
    } else {
        res.status = 400;
        res.body = "error: missing body in request\n";
    }
}
