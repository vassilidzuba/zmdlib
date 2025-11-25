const std = @import("std");
const httpz = @import("httpz");
const zmdlib = @import("zmdlib");

pub fn main() !void {
    std.debug.print("starting to wait for requests\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = try httpz.Server(void).init(allocator, .{ .port = 8080 }, {});
    defer {
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});
    router.post("/tohtml", toHtml, .{});

    // blocks
    try server.listen();
}

fn toHtml(req: *httpz.Request, res: *httpz.Response) !void {
    // TODO/ shout be improved !!!
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
