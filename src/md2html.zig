// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const parser = @import("./parser.zig");

pub fn md2htmlFile(allocator: *const std.mem.Allocator, path: [:0]const u8, output: ?std.fs.File) !void {
    var it = try parser.parseFile(allocator, path);
    defer it.deinit();

    if (output) |out| {
        try convert(&it, out);
    } else {
        try convert(&it, std.fs.File.stdout());
    }
}

pub fn md2html(text: []const u8) !void {
    var it = try parser.parse(text);
    try convert(&it, std.fs.File.stdout());
}

fn convert(it: *parser.Iterator, out: std.fs.File) !void {
    while (true) {
        const elem = try parser.next(it);

        _ = switch (elem.type) {
            parser.ElemType.startDocument => try out.write("<html><doc>\n"),
            parser.ElemType.endDocument => {
                _ = try out.write("</doc></html>\n");
                break;
            },
            parser.ElemType.startHead1 => try out.write("<h1>"),
            parser.ElemType.endHead1 => try out.write("</h1>\n"),
            parser.ElemType.startHead2 => try out.write("<h2>"),
            parser.ElemType.endHead2 => try out.write("</h2>\n"),
            parser.ElemType.startHead3 => try out.write("<h3>"),
            parser.ElemType.endHead3 => try out.write("</h3>\n"),
            parser.ElemType.startHead4 => try out.write("<h4>"),
            parser.ElemType.endHead4 => try out.write("</h4>\n"),
            parser.ElemType.startHead5 => try out.write("<h5>"),
            parser.ElemType.endHead5 => try out.write("</h5>\n"),
            parser.ElemType.startHead6 => try out.write("<h6>"),
            parser.ElemType.endHead6 => try out.write("</h6>\n"),
            parser.ElemType.startBlockquote => try out.write("<blockquote>\n"),
            parser.ElemType.endBlockquote => try out.write("</blockquote>\n"),
            parser.ElemType.startPara => try out.write("<p>"),
            parser.ElemType.endPara => try out.write("</p>\n"),
            parser.ElemType.startBold => try out.write("<strong>"),
            parser.ElemType.endBold => try out.write("</strong>"),
            parser.ElemType.startItalic => try out.write("<em>"),
            parser.ElemType.endItalic => try out.write("</em>"),
            parser.ElemType.startBoldItalic => try out.write("<em><strong>"),
            parser.ElemType.endBoldItalic => try out.write("</strong></em>"),
            parser.ElemType.startCode => try out.write("<code>"),
            parser.ElemType.endCode => try out.write("</code>"),
            parser.ElemType.startCodeBlock => try out.write("<pre><code>"),
            parser.ElemType.endCodeBlock => try out.write("</code></pre>\n"),
            parser.ElemType.horizontalRule => try out.write("<hr />\n"),
            parser.ElemType.lineBreak => try out.write("<br />\n"),
            parser.ElemType.text => try out.write(elem.content.?),
            parser.ElemType.noop => {},
            else => std.debug.print("??? {any}\n", .{elem.type}),
        };
    }
}

test "one" {
    const ta = std.testing.allocator;
    try md2htmlFile(ta, "testdata/md01.md");
}
