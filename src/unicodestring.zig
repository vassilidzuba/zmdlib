// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");

pub const UnicodeStringError = error{
    atendofdata,
    badunicodechar,
};

pub const UnicodeString = struct {
    data: []const u8,
    pos: usize = 0,
    posmark: usize = 0,
    curchar: []const u8 = undefined,

    pub fn getNextChar(self: *UnicodeString) bool {
        const newpos, const value = self.parseChar(self.pos) catch .{ 0, 0 };
        if (value == 0) {
            return false;
        }
        self.curchar = self.data[self.pos..newpos];
        self.pos = newpos;
        return true;
    }

    pub fn lookNextChar(self: *UnicodeString) !u21 {
        _, const value = try self.parseChar(self.pos);
        return value;
    }

    pub fn lookNextCharAt(self: *UnicodeString, pos: usize) !u21 {
        _, const value = try self.parseChar(self.pos + pos);
        return value;
    }

    fn parseChar(self: *UnicodeString, pos: usize) !struct { usize, u21 } {
        if (pos >= self.data.len) {
            return UnicodeStringError.atendofdata;
        }
        const len = std.unicode.utf8ByteSequenceLength(self.data[pos]) catch 0;
        if (pos + len > self.data.len) {
            return UnicodeStringError.atendofdata;
        }
        const value = switch (len) {
            1 => self.data[pos],
            2 => {
                var data: [2]u8 = undefined;
                data[0] = self.data[pos];
                data[1] = self.data[pos + 1];
                return .{ pos + len, try std.unicode.utf8Decode2(data) };
            },
            3 => {
                var data: [3]u8 = undefined;
                data[0] = self.data[pos];
                data[1] = self.data[pos + 1];
                data[2] = self.data[pos + 2];
                return .{ pos + len, try std.unicode.utf8Decode3(data) };
            },
            4 => {
                var data: [4]u8 = undefined;
                data[0] = self.data[pos];
                data[1] = self.data[pos + 1];
                data[2] = self.data[pos + 2];
                data[2] = self.data[pos + 3];
                return .{ pos + len, try std.unicode.utf8Decode4(data) };
            },
            else => return UnicodeStringError.badunicodechar,
        };

        return .{ pos + len, value };
    }

    pub inline fn getCurChar(chptr: *UnicodeString) []const u8 {
        return chptr.curchar;
    }

    pub fn peek(self: *UnicodeString, prefix: []const u8) bool {
        return self.peekAt(prefix, 0);
    }

    pub fn peekAt(self: *UnicodeString, prefix: []const u8, pos: usize) bool {
        var pos1 = self.pos + pos;
        var pos2: usize = 0;
        while (true) {
            if (pos2 >= prefix.len) {
                return true;
            }
            if (pos1 >= self.data.len) {
                return false;
            }
            const len1 = std.unicode.utf8ByteSequenceLength(self.data[pos1]) catch 0;
            const len2 = std.unicode.utf8ByteSequenceLength(prefix[pos2]) catch 0;
            if (len1 != len2) {
                std.debug.print("yup\n", .{});
                return false;
            }
            for (0..len1) |_| {
                if (self.data[pos1] != prefix[pos2]) {
                    return false;
                }
                pos1 = pos1 + 1;
                pos2 = pos2 + 1;
            }
        }
    }

    pub inline fn eod(self: *UnicodeString) bool {
        return self.pos >= self.data.len;
    }

    pub fn skipNL(self: *UnicodeString) void {
        const data = self.data;
        while (self.pos < data.len and (data[self.pos] == '\r' or data[self.pos] == '\n')) {
            self.pos = self.pos + 1;
        }
    }

    pub fn skipEndOfLineStrict(self: *UnicodeString) void {
        while (true) {
            if (self.eod()) {
                return;
            }

            if (self.data[self.pos] == '\n') {
                return;
            }

            _ = self.getNextChar();
        }
    }

    pub fn skipSpaces(self: *UnicodeString) void {
        const data = self.data;
        while (self.pos < data.len and (data[self.pos] == ' ' or data[self.pos] == '\t')) {
            _ = self.getNextChar();
        }
    }

    pub fn skipChars(self: *UnicodeString, nbchars: usize) void {
        for (0..nbchars) |_| {
            _ = self.getNextChar();
        }
    }

    pub fn printCurrentText(self: *UnicodeString) void {
        std.debug.print(">|", .{});
        for (0..10) |ii| {
            if (self.pos + ii < self.data.len) {
                std.debug.print("{c}", .{self.data[self.pos + ii]});
            }
        }
        std.debug.print("|\n", .{});
    }

    pub fn mark(self: *UnicodeString) void {
        self.posmark = self.pos;
    }

    pub fn atmark(self: *UnicodeString) bool {
        return self.posmark == self.pos;
    }

    pub fn reset(self: *UnicodeString) void {
        self.pos = self.posmarkl;
        self.posmark = 0;
    }

    pub fn getMarkedArea(self: *UnicodeString) []const u8 {
        return self.data[self.posmark..self.pos];
    }
};

test "unicode" {
    const text = "zorro éèà \u{03B1} \u{A455} \u{65}\u{301} 😊 orroz";

    var chptr = UnicodeString{ .data = text };

    while (!chptr.eod()) {
        const cp = try chptr.lookNextChar();
        _ = chptr.getNextChar();
        std.debug.print("--> {d} - {s}\n", .{ cp, chptr.getCurChar() });
    }

    chptr = UnicodeString{ .data = "# heading" };
    try std.testing.expect(chptr.peek("#"));
    try std.testing.expect(chptr.peek("# "));
    try std.testing.expect(!chptr.peek("#a"));
    try std.testing.expect(!chptr.peek("a"));
    try std.testing.expect(!chptr.peek("é"));
    try std.testing.expect(!chptr.peek("éè"));

    chptr = UnicodeString{ .data = "é heading" };
    try std.testing.expect(chptr.peek("é"));
    try std.testing.expect(chptr.peek("é "));
    try std.testing.expect(!chptr.peek("a"));
    try std.testing.expect(!chptr.peek("a"));
    try std.testing.expect(!chptr.peek("è"));
    try std.testing.expect(!chptr.peek("éè"));

    chptr = UnicodeString{ .data = "aé" };
    _ = chptr.getNextChar();
    _ = chptr.getNextChar();
    try std.testing.expect(chptr.eod());

    chptr = UnicodeString{ .data = "12345" };
    try std.testing.expect(chptr.peekAt("123", 0));
    try std.testing.expect(chptr.peekAt("234", 1));
    try std.testing.expectEqual(chptr.lookNextChar(), '1');
    try std.testing.expectEqual(chptr.lookNextCharAt(1), '2');
}
