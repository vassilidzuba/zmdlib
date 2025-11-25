const std = @import("std");
const ArrayList = std.ArrayList;

pub const XmlWriterError = error{
    TooManyEndTags,
    MissingEndTags,
};

const XmlWriterState = enum {
    start,
    instarttag,
    instarttagemptyelement,
};

pub const XmlWriter = struct {
    allocator: std.mem.Allocator,
    file: std.fs.File = undefined,
    stack: std.ArrayList([]const u8),
    state: XmlWriterState = .start,
    blocklevel: bool = false,

    pub fn startDoc(self: *XmlWriter) !void {
        self.stack.clearRetainingCapacity();
        self.state = .start;
        _ = try self.file.write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
    }

    pub fn endDoc(self: *XmlWriter) !void {
        if (self.stack.items.len != 0) {
            return XmlWriterError.MissingEndTags;
        }
        _ = try self.file.write("\n");
    }

    pub fn startElement(self: *XmlWriter, tag: []const u8, blocklevel: bool) !void {
        if (self.state == .instarttag) {
            _ = try self.file.write(">");
        }
        if (self.state == .instarttagemptyelement) {
            _ = try self.file.write(" />");
            if (self.blocklevel) {
                _ = try self.file.write("\n");
            }
        }
        if (blocklevel) {
            _ = try self.file.write("\n");
        }
        _ = try self.file.write("<");
        _ = try self.file.write(tag);
        const top = try self.stack.addOne(self.allocator);
        top.* = tag;
        self.state = .instarttag;
    }

    pub fn emptyElement(self: *XmlWriter, tag: []const u8, blocklevel: bool) !void {
        if (self.state == .instarttag) {
            _ = try self.file.write(">");
        }
        if (self.state == .instarttagemptyelement) {
            _ = try self.file.write(" />");
            if (self.blocklevel) {
                _ = try self.file.write("\n");
            }
        }
        _ = try self.file.write("<");
        _ = try self.file.write(tag);
        self.state = .instarttagemptyelement;
        self.blocklevel = blocklevel;
    }

    pub fn attribute(self: *XmlWriter, name: []const u8, value: []const u8) !void {
        _ = try self.file.write(" ");
        _ = try self.file.write(name);
        _ = try self.file.write("=\"");
        try writeProtectedText(value, self.file);
        _ = try self.file.write("\"");
    }

    pub fn endElement(self: *XmlWriter, blocklevel: bool) !void {
        if (self.state == .instarttag) {
            _ = try self.file.write(">");
            self.state = .start;
        }
        if (self.state == .instarttagemptyelement) {
            _ = try self.file.write(" />");
            if (self.blocklevel) {
                _ = try self.file.write("\n");
            }
            self.state = .start;
        }
        const tagopt = self.stack.pop();
        if (tagopt) |tag| {
            _ = try self.file.write("</");
            _ = try self.file.write(tag);
            _ = try self.file.write(">");
        } else {
            return XmlWriterError.TooManyEndTags;
        }
        if (blocklevel) {
            _ = try self.file.write("\n");
        }
    }

    pub fn text(self: *XmlWriter, data: []const u8) !void {
        if (self.state == .instarttag) {
            _ = try self.file.write(">");
            self.state = .start;
        }
        if (self.state == .instarttagemptyelement) {
            _ = try self.file.write(" />");
            if (self.blocklevel) {
                _ = try self.file.write("\n");
            }
            self.state = .start;
        }
        try writeProtectedText(data, self.file);
    }

    pub fn newline(self: *XmlWriter) !void {
        _ = try self.file.write("\n");
    }

    pub fn deinit(self: *XmlWriter) void {
        self.stack.deinit(self.allocator);
    }
};

fn writeProtectedText(data: []const u8, out: std.fs.File) !void {
    var startpos: usize = 0;
    var endpos: usize = 0;

    var isspace: bool = false;

    while (true) {
        endpos = endpos + 1;
        if (endpos > data.len) {
            return;
        }
        if (endpos == data.len) {
            _ = try out.write(data[startpos..endpos]);
            return;
        }

        // std.debug.print("-> {d} - {d}\n", .{ data.len, endpos });

        const ch = data[endpos];
        if (ch == '<') {
            _ = try out.write(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try out.write("&lt;");
        } else if (ch == '>') {
            _ = try out.write(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try out.write("&gt;");
        } else if (ch == '&') {
            _ = try out.write(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try out.write("&amp;");
        } else if (ch == '"') {
            _ = try out.write(data[startpos..endpos]);
            startpos = endpos + 1;
            _ = try out.write("&quot;");
        }

        isspace = false;
    }
}

test "xmlwriter mainline" {
    const ta = std.testing.allocator;

    var xw = XmlWriter{
        .allocator = ta,
        .file = std.fs.File.stdout(),
        .stack = try ArrayList([]const u8).initCapacity(ta, 20),
    };
    defer xw.deinit();

    // std.debug.print(">>> {d}\n", .{xw.stack.items.len});

    try xw.startDoc();
    try xw.startElement("html", false);
    try xw.startElement("doc", true);
    try xw.startElement("p", true);
    try xw.attribute("importance", "high");
    try xw.attribute("permanence", "infinite & beyond");
    try xw.text("Lorem & Ipsum");
    try xw.endElement(true);
    try xw.emptyElement("hr", true);
    try xw.endElement(true);
    try xw.endElement(true);
    try xw.endDoc();

    std.debug.print(">>> {d}\n", .{xw.stack.items.len});
}

test "xmlwriter errors" {
    const ta = std.testing.allocator;

    var xw = XmlWriter{
        .allocator = ta,
        .file = std.fs.File.stdout(),
        .stack = try ArrayList([]const u8).initCapacity(ta, 20),
    };
    defer xw.deinit();

    // too many endtags

    try xw.startDoc();
    try xw.startElement("doc", false);
    try xw.endElement(false);
    const err1 = xw.endElement(false);
    try std.testing.expectError(XmlWriterError.TooManyEndTags, err1);
    try xw.newline();

    // too few endtags

    try xw.startDoc();
    try xw.startElement("doc", false);
    try xw.startElement("body", true);
    try xw.endElement(false);
    const err2 = xw.endDoc();
    try std.testing.expectError(XmlWriterError.MissingEndTags, err2);
    try xw.newline();
}

test "xmlwriter unicode" {
    const ta = std.testing.allocator;

    var xw = XmlWriter{
        .allocator = ta,
        .file = std.fs.File.stdout(),
        .stack = try ArrayList([]const u8).initCapacity(ta, 20),
    };
    defer xw.deinit();

    // too many endtags

    try xw.startDoc();
    try xw.startElement("doc", false);
    try xw.text("zorro éèà \u{03B1} \u{A455} \u{65}\u{301} 😊 orroz");
    try xw.endElement(true);
}
