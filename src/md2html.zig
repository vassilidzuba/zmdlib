// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const parser = @import("./parser.zig");
const xmlwriter = @import("./xmlwriter.zig");

pub const Md2htmlConfig = struct {
    snippet: bool = false,
};

pub fn md2htmlFile(allocator: std.mem.Allocator, path: [:0]const u8, output: ?std.fs.File, config: Md2htmlConfig) !void {
    var it = try parser.parseFile(allocator, path);
    defer it.deinit();

    var xw = try getXmlWriter(allocator, output);
    defer xw.deinit();

    try convert(&it, &xw, config);
}

pub fn md2html(allocator: std.mem.Allocator, text: []const u8, output: ?std.fs.File, config: Md2htmlConfig) !void {
    var it = try parser.parse(text);

    var xw = try getXmlWriter(allocator, output);
    defer xw.deinit();

    try convert(&it, &xw, config);
}

fn getXmlWriter(allocator: std.mem.Allocator, output: ?std.fs.File) !xmlwriter.XmlWriter {
    var xw = xmlwriter.XmlWriter{
        .allocator = allocator,
        .stack = try std.ArrayList([]const u8).initCapacity(allocator, 20),
    };

    if (output) |out| {
        xw.file = out;
    } else {
        xw.file = std.fs.File.stdout();
    }

    return xw;
}

fn convert(it: *parser.Iterator, xw: *xmlwriter.XmlWriter, config: Md2htmlConfig) !void {
    var inlinktitle = false;
    var inlinkurl = false;
    var inshortlink = false;
    var linktitle: ?[]const u8 = null;
    var linkurl: ?[]const u8 = null;

    var inheading: bool = false;
    var headingbuf: [1000]u8 = undefined;
    var heading: []const u8 = undefined;
    var inpara: bool = false;

    while (true) {
        const elem = try parser.next(it);

        _ = switch (elem.type) {
            parser.ElemType.startDocument => {
                if (!config.snippet) {
                    try xw.startElement("html", true);
                    try xw.startElement("doc", true);
                }
            },
            parser.ElemType.endDocument => {
                if (!config.snippet) {
                    try xw.endElement(true);
                    try xw.endElement(true);
                }
                break;
            },
            parser.ElemType.startHead1 => try startHeading("h1", &inheading, xw),
            parser.ElemType.endHead1 => try endHeading(&inheading, xw),
            parser.ElemType.startHead2 => try startHeading("h2", &inheading, xw),
            parser.ElemType.endHead2 => try endHeading(&inheading, xw),
            parser.ElemType.startHead3 => try startHeading("h3", &inheading, xw),
            parser.ElemType.endHead3 => try endHeading(&inheading, xw),
            parser.ElemType.startHead4 => try startHeading("h4", &inheading, xw),
            parser.ElemType.endHead4 => try endHeading(&inheading, xw),
            parser.ElemType.startHead5 => try startHeading("h5", &inheading, xw),
            parser.ElemType.endHead5 => try endHeading(&inheading, xw),
            parser.ElemType.startHead6 => try startHeading("h6", &inheading, xw),
            parser.ElemType.endHead6 => try endHeading(&inheading, xw),
            parser.ElemType.startBlockquote => try xw.startElement("blockquote", true),
            parser.ElemType.endBlockquote => try xw.endElement(true),
            parser.ElemType.startPara => try startPara(&inpara, xw),
            parser.ElemType.endPara => try endPara(&inpara, xw),
            parser.ElemType.startBold => try xw.startElement("strong", false),
            parser.ElemType.endBold => try xw.endElement(false),
            parser.ElemType.startItalic => try xw.startElement("em", false),
            parser.ElemType.endItalic => try xw.endElement(false),
            parser.ElemType.startBoldItalic => {
                try xw.startElement("em", false);
                try xw.startElement("strong", false);
            },
            parser.ElemType.endBoldItalic => {
                try xw.endElement(false);
                try xw.endElement(false);
            },
            parser.ElemType.startCode => try xw.startElement("code", false),
            parser.ElemType.endCode => try xw.endElement(false),
            parser.ElemType.startCodeBlock => {
                try xw.startElement("pre", false);
                try xw.startElement("code", false);
            },
            parser.ElemType.endCodeBlock => {
                try xw.endElement(false);
                try xw.endElement(true);
            },
            parser.ElemType.horizontalRule => try xw.emptyElement("hr", true),
            parser.ElemType.lineBreak => try xw.emptyElement("br", true),
            parser.ElemType.text => {
                if (inlinktitle) {
                    linktitle = elem.content.?;
                } else if (inlinktitle) {
                    try writeProtectedText(elem.content.?, xw, true);
                } else if (inlinkurl) {
                    linkurl = elem.content.?;
                } else if (inheading) {
                    heading = copyHeading(&headingbuf, elem.content.?);
                    try xw.attribute("id", heading);
                    try writeProtectedText(elem.content.?, xw, false);
                } else if (inshortlink) {
                    try writeShortLink(elem.content.?, xw);
                } else {
                    try writeProtectedText(elem.content.?, xw, inpara);
                }
            },
            parser.ElemType.startLink => {},
            parser.ElemType.startLinkTitle => inlinktitle = true,
            parser.ElemType.endLinkTitle => inlinktitle = false,
            parser.ElemType.startLinkUrl => inlinkurl = true,
            parser.ElemType.endLinkUrl => inlinkurl = false,
            parser.ElemType.endLink => {
                try xw.startElement("a", false);
                try xw.attribute("href", linkurl.?);
                try writeProtectedText(linktitle.?, xw, false);
                try xw.endElement(false);
            },
            parser.ElemType.startShortLink => inshortlink = true,
            parser.ElemType.endShortLink => inshortlink = false,
            parser.ElemType.startUnorderedList => {
                try xw.startElement("ul", false);
                try xw.text("\n");
            },
            parser.ElemType.endUnorderedList => try xw.endElement(true),
            parser.ElemType.startUnorderedListItem => try xw.startElement("li", false),
            parser.ElemType.endUnorderedListItem => try xw.endElement(true),
            parser.ElemType.noop => {},
            else => std.debug.print("??? {any}\n", .{elem.type}),
        };
    }
}

fn writeShortLink(data: []const u8, xw: *xmlwriter.XmlWriter) !void {
    try xw.startElement("a", false);
    if (isMailAddress(data)) {
        // 127 should be enough for a meli address
        var data2: [128]u8 = undefined;
        std.mem.copyForwards(u8, &data2, "mailto:");
        std.mem.copyForwards(u8, data2[7..], data);
        try xw.attribute("href", data2[0 .. 7 + data.len]);

        // "<a href=\"mailto:");
        try xw.attribute("class", "email");
    } else {
        try xw.attribute("href", data);
        try xw.attribute("class", "uri");
    }
    try xw.text(data);
    try xw.endElement(false);
}

fn writeProtectedText(data: []const u8, xw: *xmlwriter.XmlWriter, inpara: bool) !void {
    var startpos: usize = 0;
    var endpos: usize = 0;

    var isspace: bool = false;

    if (data.len == 0) {
        return;
    }

    while (true) {
        endpos = endpos + 1;
        if (endpos == data.len) {
            try xw.text(data[startpos..endpos]);
            return;
        }

        const ch = data[endpos];
        if (ch == '<') {
            _ = try xw.text(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try xw.text("&lt;");
        } else if (ch == '>') {
            _ = try xw.text(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try xw.text("&gt;");
        } else if (ch == '&') {
            _ = try xw.text(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try xw.text("&amp;");
        } else if (ch == '"') {
            _ = try xw.text(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try xw.text("&quot;");
        } else if (ch == ' ') {
            if (isspace and inpara) {
                _ = try xw.text(data[startpos..endpos]);
                startpos = endpos + 1;
            } else {
                isspace = true;
            }
            continue;
        } else if (ch == '\r' and inpara) {
            _ = try xw.text(data[startpos..endpos]);
            startpos = endpos + 1;
            if (isspace and inpara) {
                continue;
            }
        } else if (ch == '\n' and inpara) {
            _ = try xw.text(data[startpos..endpos]);
            startpos = endpos + 1;
            if (isspace and inpara) {
                continue;
            }
            _ = try xw.text(" ");
        }

        isspace = false;
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

pub fn displayEvents(allocator: std.mem.Allocator, path: [:0]const u8) !void {
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

fn copyHeading(heading: []u8, data: []const u8) []const u8 {
    //std.debug.print("\nyep {s} {d}\n", .{ data, heading.len });

    var pos: usize = 0;

    for (data) |ch| {
        if (ch == ' ') {
            heading[pos] = '-';
        } else if (ch == '.' and pos == 0) {
            continue;
        } else if (ch >= 'A' and ch <= 'Z') {
            const ch2 = ch + ('a' - 'A');
            heading[pos] = ch2;
        } else if (ch == ',') {
            heading[pos] = '.';
        } else {
            heading[pos] = ch;
        }
        pos = pos + 1;
    }

    return heading[0..pos];
}

fn startHeading(tag: []const u8, flag: *bool, xw: *xmlwriter.XmlWriter) !void {
    _ = try xw.startElement(tag, false);
    flag.* = true;
}

fn endHeading(flag: *bool, xw: *xmlwriter.XmlWriter) !void {
    _ = try xw.endElement(true);
    flag.* = false;
}

fn startPara(flag: *bool, xw: *xmlwriter.XmlWriter) !void {
    try xw.startElement("p", false);
    flag.* = true;
}

fn endPara(flag: *bool, xw: *xmlwriter.XmlWriter) !void {
    try xw.endElement(true);
    flag.* = false;
}

test "one" {
    const ta = std.testing.allocator;
    try md2htmlFile(ta, "testdata/md01.md", null, .{});
}

test "writeprotected" {
    const out = std.fs.File.stdout();
    const ta = std.testing.allocator;
    var xw = try getXmlWriter(ta, out);
    defer xw.deinit();

    try writeProtectedText("alpha < beta & gamma.\n", &xw, false);
}

test "mailto" {
    const out = std.fs.File.stdout();
    const ta = std.testing.allocator;
    var xw = try getXmlWriter(ta, out);
    defer xw.deinit();

    try writeShortLink("myself@google.com", &xw);
    try xw.newline();
}

test "heading" {
    const ta = std.testing.allocator;
    const text =
        \\# Horrendous Title
        \\
        \\some data
    ;

    try md2html(ta, text, std.fs.File.stdout(), .{});
}

test "para" {
    const ta = std.testing.allocator;
    const text =
        \\# Horrendous Title
        \\
        \\Some data.
        \\And more data.
    ;

    try md2html(ta, text, std.fs.File.stdout(), .{});
}
