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
    var inlinktitle = false;
    var inlinkurl = false;
    var inshortlink = false;
    var linktitle: ?[]const u8 = null;
    var linkurl: ?[]const u8 = null;

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
            parser.ElemType.text => {
                if (inlinktitle) {
                    linktitle = elem.content.?;
                } else if (inlinkurl) {
                    linkurl = elem.content.?;
                } else if (inshortlink) {
                    try writeShortLink(elem.content.?, out);
                } else {
                    _ = try writeProtectedText(elem.content.?, out);
                }
            },
            parser.ElemType.startLink => {},
            parser.ElemType.startLinkTitle => inlinktitle = true,
            parser.ElemType.endLinkTitle => inlinktitle = false,
            parser.ElemType.startLinkUrl => inlinkurl = true,
            parser.ElemType.endLinkUrl => inlinkurl = false,
            parser.ElemType.endLink => {
                _ = try out.write("<a href=\"");
                _ = try writeProtectedText(linkurl.?, out);
                _ = try out.write("\">");
                _ = try writeProtectedText(linktitle.?, out);
                _ = try out.write("</a>");
            },
            parser.ElemType.startShortLink => inshortlink = true,
            parser.ElemType.endShortLink => inshortlink = false,
            parser.ElemType.startUnorderedList => try out.write("<ul>\n"),
            parser.ElemType.endUnorderedList => try out.write("</ul>\n"),
            parser.ElemType.startUnorderedListItem => try out.write("<li>"),
            parser.ElemType.endUnorderedListItem => try out.write("</li>\n"),
            parser.ElemType.noop => {},
            else => std.debug.print("??? {any}\n", .{elem.type}),
        };
    }
}

fn writeShortLink(data: []const u8, out: std.fs.File) !void {
    if (isMailAddress(data)) {
        _ = try out.write("<a href=\"mailto:");
        _ = try writeProtectedText(data, out);
        _ = try out.write("\" class=\"email\">");
        _ = try writeProtectedText(data, out);
        _ = try out.write("</a>");
    } else {
        _ = try out.write("<a href=\"");
        _ = try writeProtectedText(data, out);
        _ = try out.write("\" class=\"uri\">");
        _ = try writeProtectedText(data, out);
        _ = try out.write("</a>");
    }
}

fn writeProtectedText(data: []const u8, out: std.fs.File) !void {
    var startpos: usize = 0;
    var endpos: usize = 0;

    while (true) {
        endpos = endpos + 1;
        if (endpos == data.len) {
            _ = try out.write(data[startpos..endpos]);
            return;
        }

        const ch = data[endpos];
        if (ch == '<') {
            _ = try out.write(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try out.write("&lt;");
        } else if (ch == '&') {
            _ = try out.write(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try out.write("&amp;");
        }
    }
}

fn isMailAddress(data: []const u8) bool {
    // test should be more precise
    for (data) |c| {
        if (c == '@') {
            return true;
        }
    }
    return false;
}

pub fn displayEvents(allocator: *const std.mem.Allocator, path: [:0]const u8) !void {
    var it = try parser.parseFile(allocator, path);
    defer it.deinit();

    while (true) {
        const elem = try parser.next(&it);

        if (elem.type == parser.ElemType.endDocument) {
            return;
        }

        if (elem.type == parser.ElemType.text) {
            std.debug.print(">    {s}\n", .{elem.content.?});
        } else {
            std.debug.print("> {any}\n", .{elem.type});
        }
    }
}

test "one" {
    const ta = std.testing.allocator;
    try md2htmlFile(ta, "testdata/md01.md");
}

test "writeprotected" {
    const out = std.fs.File.stdout();

    try writeProtectedText("alpha < beta & gamma.\n", out);
}
