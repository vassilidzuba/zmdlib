const std = @import("std");
const cli = @import("cli");
const httpz = @import("httpz");
const zmdlib = @import("zmdlib");

const random_bytes_count = 12;
const random_path_len = std.fs.base64_encoder.calcSize(random_bytes_count);

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

const App = struct {
    pub fn notFound(_: *App, req: *httpz.Request, res: *httpz.Response) !void {
        std.log.info("404 {} {s}", .{ req.method, req.url.path });
        res.status = 404;
        res.body = "Not Found";
    }
};

fn runserver(allocator: std.mem.Allocator) !void {
    const port = getPort();
    std.log.info("Listening to port {d}", .{port});

    var app = App{};

    var server = try httpz.Server(*App).init(allocator, .{ .port = port }, &app);
    defer {
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});
    router.post("/tohtml", toHtml, .{});

    // blocks
    try server.listen();
}

fn getPort() u16 {
    if (config.port) |port| {
        return std.fmt.parseInt(u16, port, 10) catch {
            std.log.err("illegal port number: {s}", .{port});
            std.os.linux.exit(3);
        };
    } else {
        return 8080;
    }
}

fn toHtml(_: *App, req: *httpz.Request, res: *httpz.Response) !void {
    // TODO/ shout be improved to allow some parralelism!!!
    const tempfilename = try getTempFile(res.arena);

    if (req.body()) |body| {
        std.log.info("received request ({d} bytes)", .{body.len});
        if (req.header("content-type")) |ct| {
            if (!std.mem.eql(u8, ct, "text/markdown")) {
                res.status = 400;
                res.body = "error: content-type should be text/markdown\n";
                std.log.err("content-type should be text/markdown", .{});
                return;
            }
        }

        res.status = 200;

        const file = try std.fs.cwd().createFile(
            tempfilename,
            .{ .read = true },
        );
        defer std.fs.deleteFileAbsolute(tempfilename) catch {};
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
        std.log.err("missing body in request", .{});
    }
}

fn getTempFile(allocator: std.mem.Allocator) ![]const u8 {
    const tmpdir = try getTempDir(allocator);
    defer allocator.free(tmpdir);

    const fileprefix = "/tohtmlsrv-";
    const filesuffix = ".md";
    var random_bytes: [random_bytes_count]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    var random_path: [random_path_len]u8 = undefined;
    _ = std.fs.base64_encoder.encode(&random_path, &random_bytes);

    const filepath = try allocator.alloc(u8, tmpdir.len + fileprefix.len + random_path_len + filesuffix.len);
    copy(filepath, tmpdir, 0);
    copy(filepath, fileprefix, tmpdir.len);
    copy(filepath, &random_path, tmpdir.len + fileprefix.len);
    copy(filepath, filesuffix, tmpdir.len + fileprefix.len + random_path_len);
    return filepath;
}

fn copy(dest: []u8, src: []const u8, pos: usize) void {
    for (0..src.len) |ii| {
        dest[pos + ii] = src[ii];
    }
}

fn getTempDir(allocator: std.mem.Allocator) ![]u8 {
    if (std.process.hasNonEmptyEnvVarConstant("TMPDIR")) {
        return try std.process.getEnvVarOwned(allocator, "TMPDIR");
    } else {
        return std.mem.Allocator.dupe(allocator, u8, "/tmp");
    }
}
