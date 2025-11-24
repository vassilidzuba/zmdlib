const std = @import("std");
const zmdlib = @import("./root.zig");

test "nonreg para single line" {
    const in =
        \\Lorem ipsum.
    ;
    const out =
        \\<p>Lorem ipsum.</p>
        \\
    ;

    try runTest(in, out);
}

test "nonreg para multi line" {
    const in =
        \\Lorem ipsum
        \\dolor si amet.
    ;
    const out =
        \\<p>Lorem ipsum dolor si amet.</p>
        \\
    ;

    try runTest(in, out);
}

test "nonreg para multi para" {
    const in =
        \\Lorem ipsum
        \\dolor si amet.
        \\
        \\Lorem ipsum
        \\dolor si amet.
    ;
    const out =
        \\<p>Lorem ipsum dolor si amet.</p>
        \\<p>Lorem ipsum dolor si amet.</p>
        \\
    ;

    try runTest(in, out);
}

test "nonreg italic" {
    const in =
        \\Lorem *ipsum*
        \\dolor *si* amet.
        \\
        \\Lorem _ipsum_
        \\dolor _si_ amet.
    ;
    const out =
        \\<p>Lorem <em>ipsum</em> dolor <em>si</em> amet.</p>
        \\<p>Lorem <em>ipsum</em> dolor <em>si</em> amet.</p>
        \\
    ;

    try runTest(in, out);
}

test "nonreg bold" {
    const in =
        \\Lorem **ipsum**
        \\dolor **si** amet.
        \\
        \\Lorem __ipsum__
        \\dolor __si__ amet.
    ;
    const out =
        \\<p>Lorem <strong>ipsum</strong> dolor <strong>si</strong> amet.</p>
        \\<p>Lorem <strong>ipsum</strong> dolor <strong>si</strong> amet.</p>
        \\
    ;

    try runTest(in, out);
}

test "nonreg bolditalic" {
    const in =
        \\Lorem ***ipsum***
        \\dolor ***si*** amet.
        \\
        \\Lorem ___ipsum___
        \\dolor ___si___ amet.
    ;
    const out =
        \\<p>Lorem <em><strong>ipsum</strong></em> dolor <em><strong>si</strong></em> amet.</p>
        \\<p>Lorem <em><strong>ipsum</strong></em> dolor <em><strong>si</strong></em> amet.</p>
        \\
    ;

    try runTest(in, out);
}

fn runTest(in: []const u8, out: []const u8) !void {
    const ta = std.testing.allocator;
    const tmppath = "/tmp/out.md";

    std.debug.print("\ntesting |{s}|\n", .{in});

    const file = try std.fs.createFileAbsolute(tmppath, .{});

    var in2 = try std.mem.Allocator.dupe(ta, u8, in);
    defer ta.free(in2);
    for (0..in.len) |ii| {
        if (in[ii] == '$') {
            in2[ii] = ' ';
        } else {
            in2[ii] = in[ii];
        }
    }

    try zmdlib.md2htmlText(ta, in2, file, .{ .snippet = true });

    file.close();

    const file2 = try std.fs.openFileAbsolute(tmppath, .{});
    defer file2.close();

    const file_size = try file2.getEndPos();
    const buffer = try ta.alloc(u8, file_size);
    defer ta.free(buffer);
    _ = try file2.readAll(buffer);

    std.debug.print("--> |{s}|\n--> |{s}|\n", .{ out, buffer });

    try std.testing.expectEqualSlices(u8, out, buffer);
}
