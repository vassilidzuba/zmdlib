const std = @import("std");
const parser = @import("./parser.zig");

pub fn md2htmlFile(allocator: std.mem.Allocator, path: [:0]const u8) !void {
    var it = try parser.parseFile(allocator, path);
    defer it.deinit();
    try convert(&it);
}

pub fn md2html(text: []const u8) !void {
    var it = try parser.parse(text);
    try convert(&it);
}

fn convert(it: *parser.Iterator) !void {
    while (true) {
        const elem = try parser.next(it);

        switch (elem.type) {
            parser.ElemType.startDocument => std.debug.print("<html><doc>\n", .{}),
            parser.ElemType.endDocument => {
                std.debug.print("</doc></html>\n", .{});
                break;
            },
            parser.ElemType.startHead1 => std.debug.print("<h1\n", .{}),
            parser.ElemType.endHead1 => std.debug.print("</h1>\n", .{}),
            parser.ElemType.startHead2 => std.debug.print("<h2>\n", .{}),
            parser.ElemType.endHead2 => std.debug.print("</h2>\n", .{}),
            parser.ElemType.startHead3 => std.debug.print("<h3>\n", .{}),
            parser.ElemType.endHead3 => std.debug.print("</h3>\n", .{}),
            parser.ElemType.startHead4 => std.debug.print("<h4>\n", .{}),
            parser.ElemType.endHead4 => std.debug.print("</h4>\n", .{}),
            parser.ElemType.startHead5 => std.debug.print("<h5>\n", .{}),
            parser.ElemType.endHead5 => std.debug.print("</h5>\n", .{}),
            parser.ElemType.startHead6 => std.debug.print("<h6>\n", .{}),
            parser.ElemType.endHead6 => std.debug.print("</h6>\n", .{}),
            parser.ElemType.startBlockquote => std.debug.print("<blockquote>\n", .{}),
            parser.ElemType.endBlockquote => std.debug.print("</blockquote>\n", .{}),
            parser.ElemType.startPara => std.debug.print("<p>\n", .{}),
            parser.ElemType.endPara => std.debug.print("</p>\n", .{}),
            parser.ElemType.startBold => std.debug.print("<strong>\n", .{}),
            parser.ElemType.endBold => std.debug.print("</strong>\n", .{}),
            parser.ElemType.text => std.debug.print("{s}\n", .{elem.content.?}),
            parser.ElemType.noop => {},
            else => std.debug.print("??? {any}\n", .{elem.type}),
        }
    }
}

test "one" {
    const ta = std.testing.allocator;
    try md2htmlFile(ta, "testdata/md01.md");
}
