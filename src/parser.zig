// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const unicodestring = @import("./unicodestring.zig");

const UnicodeString = unicodestring.UnicodeString;

const CommandLineParserError = error{
    BadState,
    StateStackError,
};

const State = enum {
    start,
    indoc,
    inhead1,
    inhead2,
    inhead3,
    inhead4,
    inhead5,
    inhead6,
    inpara,
    inbold,
    inboldalt,
    initalic,
    initalicalt,
    inbolditalic,
    inbolditalicalt,
    incode,
    incodeblock,
    inlink,
    inlinktitle,
    inlinkurl,
    inshortlink,
    inunorderedlist,
    inunorderedlistitem,
    leavingpara,
    leavinghead1,
    leavinghead2,
    leavinghead3,
    leavinghead4,
    leavinghead5,
    leavinghead6,
    inblockquote,
    leavingblockquote,
    leavingbold,
    leavingboldalt,
    leavingitalic,
    leavingitalicalt,
    leavingbolditalic,
    leavingbolditalicalt,
    leavingcode,
    leavinglink,
    leavinglinktitle,
    leavinglinkurl,
    leavingshortlink,
    leavingunorderedlist,
    leavingunorderedlistitem,
    end,
    undef,
};

pub const ElemType = enum {
    startDocument,
    endDocument,
    startHead1,
    startHead2,
    startHead3,
    startHead4,
    startHead5,
    startHead6,
    startBlockquote,
    startBold,
    startItalic,
    startBoldItalic,
    startCode,
    startCodeBlock,
    startPara,
    startLink,
    startLinkTitle,
    startLinkUrl,
    startShortLink,
    startUnorderedList,
    startUnorderedListItem,
    endHead1,
    endHead2,
    endHead3,
    endHead4,
    endHead5,
    endHead6,
    endBlockquote,
    endPara,
    endBold,
    endItalic,
    endBoldItalic,
    endCode,
    endCodeBlock,
    endLink,
    endLinkTitle,
    endLinkUrl,
    endShortLink,
    endUnorderedList,
    endUnorderedListItem,
    horizontalRule,
    text,
    lineBreak,
    noop,
    bad,
};

pub const Element = struct {
    type: ElemType,
    content: ?[]const u8 = null,
};

pub const Iterator = struct {
    allocator: ?std.mem.Allocator = null,
    tobefreed: ?[]u8 = null,
    data: UnicodeString,
    states: [5]State = .{ State.start, State.undef, State.undef, State.undef, State.undef },
    state_idx: usize = 0,
    pending_element: ?Element = null,

    pub fn deinit(self: *Iterator) void {
        if (self.tobefreed) |tobefreed| {
            self.allocator.?.free(tobefreed);
        }
    }

    fn getState(self: *Iterator) State {
        return self.states[self.state_idx];
    }

    fn setState(self: *Iterator, state: State) void {
        self.states[self.state_idx] = state;
    }

    fn pushState(self: *Iterator, state: State) void {
        self.state_idx = self.state_idx + 1;
        self.states[self.state_idx] = state;
    }

    fn popState(self: *Iterator) !State {
        if (self.state_idx == 0) {
            return CommandLineParserError.StateStackError;
        } else {
            self.state_idx = self.state_idx - 1;
            return self.states[self.state_idx];
        }
    }

    inline fn getNextChar(self: *Iterator) bool {
        return self.data.getNextChar();
    }

    inline fn lookNextChar(self: *Iterator) !u21 {
        return self.data.lookNextChar();
    }

    inline fn lookNextCharAt(self: *Iterator, pos: usize) !u21 {
        return self.data.lookNextCharAt(pos);
    }

    fn skip(self: *Iterator, nbchars: usize) bool {
        for (0..nbchars) |_| {
            if (!self.data.getNextChar()) {
                return false;
            }
        }
        return true;
    }

    inline fn peek(self: *Iterator, prefix: []const u8) bool {
        return self.data.peek(prefix);
    }

    inline fn peekAt(self: *Iterator, prefix: []const u8, pos: usize) bool {
        return self.data.peekAt(prefix, pos);
    }

    inline fn peekAfter(self: *Iterator, prefix: []const u8, pos: isize) bool {
        const datapos: isize = @intCast(self.data.pos);
        const delta: isize = datapos + pos;
        return self.data.peekAt(prefix, @intCast(delta));
    }

    inline fn eod(self: *Iterator) bool {
        return self.data.eod();
    }

    inline fn skipNL(self: *Iterator) void {
        self.data.skipNL();
    }

    inline fn skipEndOfLineStrict(self: *Iterator) void {
        self.data.skipEndOfLineStrict();
    }

    inline fn skipSpaces(self: *Iterator) void {
        self.data.skipSpaces();
    }

    inline fn skipChars(self: *Iterator, nbchars: usize) void {
        self.data.skipChars(nbchars);
    }

    inline fn mark(self: *Iterator) void {
        self.data.mark();
    }

    inline fn atmark(self: *Iterator) bool {
        return self.data.atmark();
    }

    inline fn reset(self: *Iterator) void {
        self.data.reset();
    }

    inline fn getMarkedArea(self: *Iterator) []const u8 {
        return self.data.getMarkedArea();
    }
};

pub fn mkIterator(text: []const u8) Iterator {
    const us = UnicodeString{ .data = text };
    return Iterator{ .data = us };
}

pub fn parse(text: []const u8) !Iterator {
    const us = UnicodeString{ .data = text };
    return Iterator{ .data = us };
}

pub fn parseFile(allocator: std.mem.Allocator, path: [:0]const u8) !Iterator {
    const buffer = try getBuffer(allocator, path);

    const us = UnicodeString{ .data = buffer };

    return Iterator{
        .allocator = allocator,
        .tobefreed = buffer,
        .data = us,
    };
}

fn getBuffer(allocator: std.mem.Allocator, path: [:0]const u8) ![]u8 {
    if (std.mem.eql(u8, path, "-")) {
        const stdin_buffer = try allocator.alloc(u8, 1024);
        defer allocator.free(stdin_buffer);

        const read_buffer_size: usize = 10;
        const read_buffer = try allocator.alloc(u8, read_buffer_size);
        defer allocator.free(read_buffer);

        var buffer_used: usize = 0;
        var buffer = try allocator.alloc(u8, read_buffer_size);

        var stdin_reader = std.fs.File.stdin().reader(stdin_buffer);
        var stdin = &stdin_reader.interface;
        while (true) {
            const nbbytes = try stdin.readSliceShort(read_buffer);
            if (buffer_used + nbbytes > buffer.len) {
                buffer = try allocator.realloc(buffer, buffer_used + nbbytes);
            }
            for (0..nbbytes) |ii| {
                buffer[buffer_used + ii] = read_buffer[ii];
            }
            buffer_used = buffer_used + nbbytes;
            if (nbbytes < read_buffer_size) {
                return try allocator.realloc(buffer, buffer_used);
            }
        }
    } else {
        var file: std.fs.File = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const file_size = try file.getEndPos();
        const buffer = try allocator.alloc(u8, file_size);
        _ = try file.readAll(buffer);
        return buffer;
    }
}

pub fn next(self: *Iterator) !Element {
    if (self.pending_element) |pe| {
        self.pending_element = null;
        return pe;
    }

    if (self.getState() == State.start) {
        self.setState(State.indoc);
        return Element{
            .type = ElemType.startDocument,
        };
    } else if (self.getState() == State.indoc) {
        self.skipNL();

        if (self.eod()) {
            self.setState(State.end);
            return Element{
                .type = ElemType.endDocument,
            };
        }

        if (self.peek("#")) {
            if (self.peek("#######")) {
                self.setState(State.inpara);
                return mkElement(ElemType.startPara);
            } else if (self.peek("######")) {
                self.setState(State.inhead6);
                self.skipChars(6);
                self.skipSpaces();
                return mkElement(ElemType.startHead6);
            } else if (self.peek("#####")) {
                self.setState(State.inhead5);
                self.skipChars(5);
                self.skipSpaces();
                return mkElement(ElemType.startHead5);
            } else if (self.peek("####")) {
                self.setState(State.inhead4);
                self.skipChars(4);
                self.skipSpaces();
                return mkElement(ElemType.startHead4);
            } else if (self.peek("###")) {
                self.setState(State.inhead3);
                self.skipChars(3);
                self.skipSpaces();
                return mkElement(ElemType.startHead3);
            } else if (self.peek("##")) {
                self.setState(State.inhead2);
                self.skipChars(2);
                self.skipSpaces();
                return mkElement(ElemType.startHead2);
            } else if (self.peek("#")) {
                self.setState(State.inhead1);
                self.skipChars(1);
                self.skipSpaces();
                return mkElement(ElemType.startHead1);
            } else {
                self.setState(State.inpara);
                return mkElement(ElemType.startPara);
            }
        } else if (self.peek("    ")) {
            self.setState(State.incodeblock);
            return mkElement(ElemType.startCodeBlock);
        } else if (self.peek("---") or self.peek("***") or self.peek("___")) {
            if (checkIsRule(self)) {
                self.skipEndOfLineStrict();
                return mkElement(ElemType.horizontalRule);
            } else {
                self.setState(State.inpara);
                return mkElement(ElemType.startPara);
            }
        } else if (self.peek(">")) {
            self.setState(State.inblockquote);
            self.skipChars(1);
            self.skipSpaces();
            return mkElement(ElemType.startBlockquote);
        } else if (self.peek("-")) {
            self.setState(State.inunorderedlist);
            return mkElement(ElemType.startUnorderedList);
        } else {
            self.setState(State.inpara);
            return mkElement(ElemType.startPara);
        }
    } else if (self.getState() == State.inpara) {
        return try processParagraph(self);
    } else if (self.getState() == State.inhead1) {
        self.setState(State.leavinghead1);
        const posstart = self.data.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        _ = self.getNextChar();
        return elem;
    } else if (self.getState() == State.inhead2) {
        self.setState(State.leavinghead2);
        const posstart = self.data.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        _ = self.getNextChar();
        return elem;
    } else if (self.getState() == State.inhead3) {
        self.setState(State.leavinghead3);
        const posstart = self.data.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        _ = self.getNextChar();
        return elem;
    } else if (self.getState() == State.inhead4) {
        self.setState(State.leavinghead4);
        const posstart = self.data.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        _ = self.getNextChar();
        return elem;
    } else if (self.getState() == State.inhead5) {
        self.setState(State.leavinghead5);
        const posstart = self.data.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        _ = self.getNextChar();
        return elem;
    } else if (self.getState() == State.inhead6) {
        self.setState(State.leavinghead6);
        const posstart = self.data.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        _ = self.getNextChar();
        return elem;
    } else if (self.getState() == State.inblockquote) {
        self.setState(State.leavingblockquote);
        const posstart = self.data.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        _ = self.getNextChar();
        return elem;
    } else if (self.getState() == State.inbold) {
        const posstart = self.data.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                _ = self.getNextChar();
                self.setState(State.leavingbold);
                break;
            } else {
                if (self.peek("**")) {
                    const elem = mkTextElement(self, posstart);
                    _ = self.getNextChar();
                    _ = self.getNextChar();
                    self.setState(State.leavingbold);
                    return elem;
                }
                _ = self.getNextChar();
            }
        }

        const elem = mkTextElement(self, posstart);
        return elem;
    } else if (self.getState() == State.inboldalt) {
        const posstart = self.data.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                _ = self.getNextChar();
                self.setState(State.leavingboldalt);
                break;
            } else {
                if (self.peek("__")) {
                    const elem = mkTextElement(self, posstart);
                    _ = self.getNextChar();
                    _ = self.getNextChar();
                    self.setState(State.leavingboldalt);
                    return elem;
                }
                _ = self.getNextChar();
            }
        }

        const elem = mkTextElement(self, posstart);
        return elem;
    } else if (self.getState() == State.initalic) {
        const posstart = self.data.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                _ = self.getNextChar();
                self.setState(State.leavingitalic);
                break;
            } else {
                if (self.peek("*")) {
                    const elem = mkTextElement(self, posstart);
                    _ = self.getNextChar();
                    self.setState(State.leavingitalic);
                    return elem;
                }
                _ = self.getNextChar();
            }
        }

        return mkTextElement(self, posstart);
    } else if (self.getState() == State.initalicalt) {
        const posstart = self.data.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                _ = self.getNextChar();
                self.setState(State.leavingitalicalt);
                break;
            } else {
                if (self.peek("_")) {
                    const elem = mkTextElement(self, posstart);
                    _ = self.getNextChar();
                    self.setState(State.leavingitalicalt);
                    return elem;
                }
                _ = self.getNextChar();
            }
        }

        return mkTextElement(self, posstart);
    } else if (self.getState() == State.inbolditalic) {
        const posstart = self.data.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                _ = self.getNextChar();
                self.setState(State.leavingbolditalic);
                break;
            } else {
                if (self.peek("***")) {
                    const elem = mkTextElement(self, posstart);
                    _ = self.getNextChar();
                    _ = self.getNextChar();
                    _ = self.getNextChar();
                    self.setState(State.leavingbolditalic);
                    return elem;
                }
                _ = self.getNextChar();
            }
        }

        return mkTextElement(self, posstart);
    } else if (self.getState() == State.inbolditalicalt) {
        const posstart = self.data.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                _ = self.getNextChar();
                self.setState(State.leavingbolditalicalt);
                break;
            } else {
                if (self.peek("___")) {
                    const elem = mkTextElement(self, posstart);
                    _ = self.getNextChar();
                    _ = self.getNextChar();
                    _ = self.getNextChar();
                    self.setState(State.leavingbolditalicalt);
                    return elem;
                }
                _ = self.getNextChar();
            }
        }

        return mkTextElement(self, posstart);
    } else if (self.getState() == State.incode) {
        const posstart = self.data.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                _ = self.getNextChar();
                self.setState(State.leavingcode);
                break;
            } else {
                if (self.peek("`")) {
                    const elem = mkTextElement(self, posstart);
                    _ = self.getNextChar();
                    self.setState(State.leavingcode);
                    return elem;
                }
                _ = self.getNextChar();
            }
        }

        return mkTextElement(self, posstart);
    } else if (self.getState() == State.incodeblock) {
        if (self.eod()) {
            self.setState(State.indoc);
            return mkElement(ElemType.endCodeBlock);
        } else if (self.peek("    ")) {
            _ = self.getNextChar();
            _ = self.getNextChar();
            _ = self.getNextChar();
            _ = self.getNextChar();
            const posstart = self.data.pos;
            self.skipEndOfLineStrict();
            if (self.data.pos + 1 < self.data.data.len and self.data.data[self.data.pos + 1] != '\n') {
                _ = self.getNextChar();
            }
            return mkTextElement(self, posstart);
        } else {
            self.setState(State.indoc);
            return mkElement(ElemType.endCodeBlock);
        }
    } else if (self.getState() == State.leavingpara) {
        self.setState(State.indoc);
        return mkElement(ElemType.endPara);
    } else if (self.getState() == State.leavinghead1) {
        self.setState(State.indoc);
        return mkElement(ElemType.endHead1);
    } else if (self.getState() == State.leavinghead2) {
        self.setState(State.indoc);
        return mkElement(ElemType.endHead2);
    } else if (self.getState() == State.leavinghead3) {
        self.setState(State.indoc);
        return mkElement(ElemType.endHead3);
    } else if (self.getState() == State.leavinghead4) {
        self.setState(State.indoc);
        return mkElement(ElemType.endHead4);
    } else if (self.getState() == State.leavinghead5) {
        self.setState(State.indoc);
        return mkElement(ElemType.endHead5);
    } else if (self.getState() == State.leavinghead6) {
        self.setState(State.indoc);
        return mkElement(ElemType.endHead6);
    } else if (self.getState() == State.leavingblockquote) {
        self.setState(State.indoc);
        return mkElement(ElemType.endBlockquote);
    } else if (self.getState() == State.leavingbold) {
        _ = try self.popState();
        if (self.peek("\n") and !self.peek("\n\n")) {
            self.pending_element = mkTextElementWithData(" ");
        }
        return mkElement(ElemType.endBold);
    } else if (self.getState() == State.leavingboldalt) {
        _ = try self.popState();
        if (self.peek("\n") and !self.peek("\n\n")) {
            self.pending_element = mkTextElementWithData(" ");
        }
        return mkElement(ElemType.endBold);
    } else if (self.getState() == State.leavingitalic) {
        _ = try self.popState();
        if (self.peek("\n") and !self.peek("\n\n")) {
            self.pending_element = mkTextElementWithData(" ");
        }
        return mkElement(ElemType.endItalic);
    } else if (self.getState() == State.leavingitalicalt) {
        _ = try self.popState();
        if (self.peek("\n") and !self.peek("\n\n")) {
            self.pending_element = mkTextElementWithData(" ");
        }
        return mkElement(ElemType.endItalic);
    } else if (self.getState() == State.leavingbolditalic) {
        _ = try self.popState();
        if (self.peek("\n") and !self.peek("\n\n")) {
            self.pending_element = mkTextElementWithData(" ");
        }
        return mkElement(ElemType.endBoldItalic);
    } else if (self.getState() == State.leavingbolditalicalt) {
        _ = try self.popState();
        if (self.peek("\n") and !self.peek("\n\n")) {
            self.pending_element = mkTextElementWithData(" ");
        }
        return mkElement(ElemType.endBoldItalic);
    } else if (self.getState() == State.leavingcode) {
        _ = try self.popState();
        if (self.peek("\n") and !self.peek("\n\n")) {
            self.pending_element = mkTextElementWithData(" ");
        }
        return mkElement(ElemType.endCode);
    } else if (self.getState() == State.inlink) {
        self.setState(State.inlinktitle);
        return mkElement(ElemType.startLinkTitle);
    } else if (self.getState() == State.inlinktitle) {
        if (self.peek("]")) {
            self.setState(State.leavinglinktitle);
            return mkElement(ElemType.endLinkTitle);
        } else {
            _ = self.getNextChar();
            const posstart = self.data.pos;
            while (!self.peek("]")) {
                _ = self.getNextChar();
            }
            return mkTextElement(self, posstart);
        }
    } else if (self.getState() == State.leavinglinktitle) {
        _ = self.getNextChar();
        self.setState(State.inlinkurl);
        return mkElement(ElemType.startLinkUrl);
    } else if (self.getState() == State.inlinkurl) {
        if (self.peek(")")) {
            self.setState(State.leavinglink);
            return mkElement(ElemType.endLinkUrl);
        } else {
            _ = self.getNextChar();
            const posstart = self.data.pos;
            while (!self.peek(")")) {
                _ = self.getNextChar();
            }
            return mkTextElement(self, posstart);
        }
    } else if (self.getState() == State.leavinglink) {
        _ = self.getNextChar();
        _ = try self.popState();
        return mkElement(ElemType.endLink);
    } else if (self.getState() == State.inshortlink) {
        if (self.peek(">")) {
            _ = try self.popState();
            _ = self.getNextChar();
            return mkElement(ElemType.endShortLink);
        } else {
            _ = self.getNextChar();
            const posstart = self.data.pos;
            while (!self.peek(">")) {
                _ = self.getNextChar();
            }
            return mkTextElement(self, posstart);
        }
    } else if (self.getState() == State.end) {
        return mkElement(ElemType.endDocument);
    } else if (self.getState() == State.inunorderedlist) {
        if (self.peek("-")) {
            _ = self.getNextChar();
            self.skipSpaces();
            self.setState(State.inunorderedlistitem);
            return mkElement(ElemType.startUnorderedListItem);
        } else {
            self.setState(State.indoc);
            return mkElement(ElemType.endUnorderedList);
        }
    } else if (self.getState() == State.inunorderedlistitem) {
        return try processUnorderedListItem(self);
    } else if (self.getState() == State.leavingunorderedlistitem) {
        self.setState(State.inunorderedlist);
        return mkElement(ElemType.endUnorderedListItem);
    } else {
        std.debug.print("unexpected state: {any}\n", .{self.getState()});
        return CommandLineParserError.BadState;
    }
}

fn mkElement(et: ElemType) Element {
    return Element{
        .type = et,
    };
}

fn mkTextElement(self: *Iterator, start: usize) Element {
    return Element{
        .type = ElemType.text,
        .content = self.data.data[start..self.data.pos],
    };
}

fn mkTextElementWithData(data: []const u8) Element {
    return Element{
        .type = ElemType.text,
        .content = data,
    };
}

fn mkLinkElement(_: *Iterator) Element {
    return Element{
        .type = ElemType.link,
    };
}

// parse a paragraph.
// Returns true if the paragraph is completed, false otherwise.
fn parseParagraph(self: *Iterator) bool {
    while (true) {
        if (self.eod()) {
            return true;
        }

        const ch = self.lookNextChar() catch 0;

        if (ch == '\n') {
            if (self.peekAt("\n", 1)) {
                return true;
            }

            if (self.getState() == State.inunorderedlistitem) {
                if (self.peek("-")) {
                    self.data.pos = self.data.pos - 1;
                    return true;
                }
            }
        }

        //std.debug.print("--> {any}", .{self.getState()});

        if (checkSpecialCharacter(ch)) {
            return false;
        }

        if (trailingWhiteSpace(self, false)) {
            return false;
        }

        _ = self.getNextChar();
    }
}

fn trailingWhiteSpace(self: *Iterator, skip: bool) bool {
    const savepos = self.data.pos;
    var nbspaces: usize = 0;
    var nbcr: usize = 0;
    var lastchar: u21 = 0;
    while (self.peek(" ") or self.peek("\r") or self.peek("\n")) {
        if (self.peek("\n")) {
            nbcr = nbcr + 1;
        }
        if (self.peek(" ")) {
            nbspaces = nbspaces + 1;
        }
        lastchar = self.lookNextChar() catch 0;
        _ = self.getNextChar();
    }

    const trailing = nbspaces >= 2 and !self.eod() and lastchar == '\n' and nbcr == 1;

    if (!(trailing and skip)) {
        self.data.pos = savepos;
    }

    return trailing;
}

fn checkLink(self: *Iterator) bool {
    const savepos = self.data.pos;
    var foundClosingBracket = false;
    var foundClosingParenthese = false;
    if (self.peek("[")) {
        _ = self.getNextChar();
        while (!self.eod() and !self.peek("\n") and !self.peek("]")) {
            _ = self.getNextChar();
        }
        if (!self.eod() and self.peek("]")) {
            _ = self.getNextChar();
            foundClosingBracket = true;
            if (!self.eod() and self.peek("(")) {
                _ = self.getNextChar();
                while (!self.eod() and !self.peek("\n") and !self.peek(")")) {
                    _ = self.getNextChar();
                }
                if (!self.eod() and self.peek(")")) {
                    foundClosingParenthese = true;
                }
            }
        }
    }

    self.data.pos = savepos;

    return foundClosingBracket and foundClosingParenthese;
}

fn checkShortLink(self: *Iterator) bool {
    var isurl = false;
    var ismail = false;
    const savepos = self.data.pos;
    if (self.peek("<")) {
        _ = self.skip(1);

        while (!self.peek("\n") and !self.peek(" ") and !self.peek(">")) {
            if (self.peek("://")) {
                isurl = true;
            }
            if (self.peek("@")) {
                ismail = true;
            }
            _ = self.getNextChar();
        }
    }

    const ret = (isurl or ismail) and self.peek(">");
    self.data.pos = savepos;
    return ret;
}

fn skipEndOfLine(self: *Iterator) bool {
    while (true) {
        if (self.eod()) {
            return true;
        }

        if (self.peek("\n")) {
            return true;
        }

        const ch = self.lookNextChar() catch 0;
        if (checkSpecialCharacter(ch)) {
            return false;
        }

        _ = self.getNextChar();
    }
}

fn advance(self: *Iterator, nbbytes: usize) bool {
    if (self.pos + nbbytes <= self.data.len) {
        self.pos = self.pos + nbbytes;
        return true;
    } else {
        self.pos = self.data.len;
        return false;
    }
}

fn checkSpecialCharacter(ch: u21) bool {
    return ch == '*' or ch == '_' or ch == '`' or ch == '[' or ch == '<';
}

fn checkIsRule(self: *Iterator) bool {
    const savepos = self.data.pos;
    const ch = self.lookNextChar() catch 0;
    while (true) {
        const ch2 = self.lookNextChar() catch 0;
        if (ch2 == ch) {
            _ = self.getNextChar();
            continue;
        } else if (ch2 == '\r' or ch2 == '\n') {
            return true;
        } else {
            return false;
        }
    }
    self.data.pos = savepos;
}

fn processUnorderedListItem(self: *Iterator) !Element {
    const elem = processParagraph(self);
    if (self.getState() == State.leavingpara) {
        self.setState(State.leavingunorderedlistitem);
    }
    return elem;
}

fn processParagraph(self: *Iterator) !Element {
    self.skipNL();

    self.mark();

    while (true) {
        if (parseParagraph(self)) {
            self.setState(State.leavingpara);
            break;
        } else {
            if (self.peek("***")) {
                if (self.atmark()) {
                    self.skipChars(3);
                    self.pushState(State.inbolditalic);
                    return mkElement(ElemType.startBoldItalic);
                }
                break;
            } else if (self.peek("___")) {
                if (self.atmark() and !self.peekAfter(" ", -1) and !self.peekAfter("\n", -1)) {
                    self.skipChars(3);
                    self.pushState(State.inbolditalicalt);
                    return mkElement(ElemType.startBoldItalic);
                } else {
                    _ = self.getNextChar();
                }
                break;
            } else if (self.peek("**")) {
                if (self.atmark()) {
                    self.skipChars(2);
                    self.pushState(State.inbold);
                    return mkElement(ElemType.startBold);
                }
                break;
            } else if (self.peek("__")) {
                if (self.atmark() and !self.peekAfter(" ", -1) and !self.peekAfter("\n", -1)) {
                    self.skipChars(2);
                    self.pushState(State.inboldalt);
                    return mkElement(ElemType.startBold);
                } else {
                    _ = self.getNextChar();
                }
                break;
            } else if (self.peek("*")) {
                if (self.atmark()) {
                    self.skipChars(1);
                    self.pushState(State.initalic);
                    return mkElement(ElemType.startItalic);
                }
                break;
            } else if (self.peek("_")) {
                if (self.atmark() and !self.peekAfter(" ", -1) and !self.peekAfter("\n", -1)) {
                    self.skipChars(1);
                    self.pushState(State.initalicalt);
                    return mkElement(ElemType.startItalic);
                } else {
                    _ = self.getNextChar();
                }
                break;
            } else if (self.peek("`")) {
                if (self.atmark()) {
                    self.skipChars(1);
                    self.pushState(State.incode);
                    return mkElement(ElemType.startCode);
                }
                break;
            } else if (checkLink(self)) {
                if (self.atmark()) {
                    self.pushState(State.inlink);
                    return mkElement(ElemType.startLink);
                }
                break;
            } else if (checkShortLink(self)) {
                if (self.atmark()) {
                    self.pushState(State.inshortlink);
                    return mkElement(ElemType.startShortLink);
                }
                break;
            } else if (trailingWhiteSpace(self, false)) {
                if (self.atmark()) {
                    _ = trailingWhiteSpace(self, true);
                    return mkElement(ElemType.lineBreak);
                }
                break;
            } else {
                _ = self.getNextChar();
            }
        }
    }

    return mkTextElementWithData(self.getMarkedArea());
}

fn printCurrentText(self: *Iterator) void {
    std.debug.print(">|", .{});
    for (0..10) |ii| {
        if (self.pos + ii < self.data.len) {
            std.debug.print("{c}", .{self.data[self.pos + ii]});
        }
    }
    std.debug.print("|\n", .{});
}

fn printCurrentTextAt(self: *Iterator, pos: usize) void {
    std.debug.print(">|", .{});
    for (0..10) |ii| {
        if (pos + ii < self.data.len) {
            if (pos + ii == self.pos) {
                std.debug.print("@@@", .{});
            }
            std.debug.print("{c}", .{self.data[pos + ii]});
        }
    }
    std.debug.print("|\n", .{});
}

test "one" {
    var it = try parse("lorem ipsum");
    while (true) {
        const elem = try next(&it);

        std.debug.print("type of element is {any}", .{
            elem.type,
        });
        if (elem.content) |content| {
            std.debug.print(": {s}", .{content});
        }

        std.debug.print("\n", .{});

        if (elem.type == ElemType.endDocument) {
            break;
        }
    }
}

test "two" {
    const ta = std.testing.allocator;

    var it = try parseFile(ta, "testdata/md02.md");
    defer it.deinit();

    while (true) {
        const elem = try next(&it);

        std.debug.print("type of element is {any}", .{
            elem.type,
        });
        if (elem.content) |content| {
            std.debug.print(": \n{s}\n", .{content});
        }

        std.debug.print("\n", .{});

        if (elem.type == ElemType.endDocument) {
            break;
        }
    }
}

test "linebreak" {
    var it = try parse("lorem ipsum   \net caetera.");
    while (true) {
        const elem = try next(&it);

        std.debug.print("type of element is {any}", .{
            elem.type,
        });
        if (elem.content) |content| {
            std.debug.print(": {s}", .{content});
        }

        std.debug.print("\n", .{});

        if (elem.type == ElemType.endDocument) {
            break;
        }
    }
}

test "checklink" {
    var it = try parse("This is [my link](http://link) ! \n");
    while (true) {
        const elem = try next(&it);

        std.debug.print("type of element is {any}", .{
            elem.type,
        });
        if (elem.content) |content| {
            std.debug.print(": {s}", .{content});
        }

        std.debug.print("\n", .{});

        if (elem.type == ElemType.endDocument) {
            break;
        }
    }
}

test "checkshortlink" {
    var it = mkIterator("<http://goo>");
    const ok = checkShortLink(&it);
    std.debug.print("is ok ? {any}\n", .{ok});
    try std.testing.expect(ok);

    try showEvents(&it);
}

test "checkshortlink2" {
    var it = mkIterator("<godybook@example.com>");
    const ok = checkShortLink(&it);
    std.debug.print("is ok ? {any}\n", .{ok});
    try std.testing.expect(ok);

    try showEvents(&it);
}

fn showEvents(it: *Iterator) !void {
    it.data.pos = 0;
    while (true) {
        const elem = try next(it);

        std.debug.print("type of element is {any}", .{
            elem.type,
        });
        if (elem.content) |content| {
            std.debug.print(": {s}", .{content});
        }

        std.debug.print("\n", .{});

        if (elem.type == ElemType.endDocument) {
            break;
        }
    }
}

fn print(text: []const u8) void {
    std.debug.print("<<<{s}>>>\n", .{text});
}

fn printNext(it: *Iterator) void {
    std.debug.print("|||{s}|||\n", .{it.data.data[it.data.pos..]});
}
