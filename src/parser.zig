// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");

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
    initalic,
    inbolditalic,
    incode,
    incodeblock,
    inlink,
    inlinktitle,
    inlinkurl,
    inshortlink,
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
    leavingitalic,
    leavingbolditalic,
    leavingcode,
    leavinglink,
    leavinglinktitle,
    leavinglinkurl,
    leavingshortlink,
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
    allocator: ?*const std.mem.Allocator = null,
    tobefreed: ?[]u8 = null,
    data: []const u8,
    pos: usize = 0,
    states: [5]State = .{ State.start, State.undef, State.undef, State.undef, State.undef },
    state_idx: usize = 0,

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
};

pub fn parse(text: []const u8) !Iterator {
    std.debug.print("parsing text <\n{s}\n>\n", .{text});
    return Iterator{ .data = text };
}

pub fn parseFile(allocator: *const std.mem.Allocator, path: [:0]const u8) !Iterator {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    _ = try file.readAll(buffer);

    return Iterator{
        .allocator = allocator,
        .tobefreed = buffer,
        .data = buffer,
    };
}

pub fn next(self: *Iterator) !Element {
    if (self.getState() == State.start) {
        self.setState(State.indoc);
        return Element{
            .type = ElemType.startDocument,
        };
    } else if (self.getState() == State.indoc) {
        skipNL(self);

        if (eod(self)) {
            self.setState(State.end);
            return Element{
                .type = ElemType.endDocument,
            };
        }

        if (self.data[self.pos] == '#') {
            if (peek(self, "#######")) {
                self.setState(State.inpara);
                return mkElement(ElemType.startPara);
            } else if (peek(self, "######")) {
                self.setState(State.inhead6);
                skipBytes(self, 6);
                skipSpaces(self);
                return mkElement(ElemType.startHead6);
            } else if (peek(self, "#####")) {
                self.setState(State.inhead5);
                skipBytes(self, 5);
                skipSpaces(self);
                return mkElement(ElemType.startHead5);
            } else if (peek(self, "####")) {
                self.setState(State.inhead4);
                skipBytes(self, 4);
                skipSpaces(self);
                return mkElement(ElemType.startHead4);
            } else if (peek(self, "###")) {
                self.setState(State.inhead3);
                skipBytes(self, 3);
                skipSpaces(self);
                return mkElement(ElemType.startHead3);
            } else if (peek(self, "##")) {
                self.setState(State.inhead2);
                skipBytes(self, 2);
                skipSpaces(self);
                return mkElement(ElemType.startHead2);
            } else if (peek(self, "#")) {
                self.setState(State.inhead1);
                skipBytes(self, 1);
                skipSpaces(self);
                return mkElement(ElemType.startHead1);
            } else {
                self.setState(State.inpara);
                return mkElement(ElemType.startPara);
            }
        } else if (peek(self, "    ")) {
            self.setState(State.incodeblock);
            return mkElement(ElemType.startCodeBlock);
        } else if (peek(self, "---") or peek(self, "***") or peek(self, "___")) {
            if (checkIsRule(self)) {
                skipEndOfLineStrict(self);
                return mkElement(ElemType.horizontalRule);
            } else {
                self.setState(State.inpara);
                return mkElement(ElemType.startPara);
            }
        } else if (peek(self, ">")) {
            self.setState(State.inblockquote);
            skipBytes(self, 1);
            skipSpaces(self);
            return mkElement(ElemType.startBlockquote);
        } else {
            self.setState(State.inpara);
            return mkElement(ElemType.startPara);
        }
    } else if (self.getState() == State.inpara) {
        skipNL(self);

        const posstart = self.pos;

        while (true) {
            if (parseParagraph(self)) {
                self.setState(State.leavingpara);
                if (!eod(self)) {
                    self.pos = self.pos + 1;
                }
                break;
            } else {
                if (peek(self, "***")) {
                    if (posstart == self.pos) {
                        self.pos = self.pos + 3;
                        self.pushState(State.inbolditalic);
                        return mkElement(ElemType.startBoldItalic);
                    }
                    break;
                } else if (peek(self, "**")) {
                    if (posstart == self.pos) {
                        self.pos = self.pos + 2;
                        self.pushState(State.inbold);
                        return mkElement(ElemType.startBold);
                    }
                    break;
                } else if (peek(self, "*")) {
                    if (posstart == self.pos) {
                        self.pos = self.pos + 1;
                        self.pushState(State.initalic);
                        return mkElement(ElemType.startItalic);
                    }
                    break;
                } else if (peek(self, "`")) {
                    if (posstart == self.pos) {
                        self.pos = self.pos + 1;
                        self.pushState(State.incode);
                        return mkElement(ElemType.startCode);
                    }
                    break;
                } else if (checkLink(self)) {
                    if (posstart == self.pos) {
                        self.pushState(State.inlink);
                        return mkElement(ElemType.startLink);
                    }
                    break;
                } else if (checkShortLink(self)) {
                    if (posstart == self.pos) {
                        self.pushState(State.inshortlink);
                        return mkElement(ElemType.startShortLink);
                    }
                    break;
                } else if (trailingWhiteSpace(self, false)) {
                    if (posstart == self.pos) {
                        _ = trailingWhiteSpace(self, true);
                        return mkElement(ElemType.lineBreak);
                    }
                    break;
                } else {
                    self.pos = self.pos + 1;
                }
            }
        }

        if (eod(self) or !peek(self, "\n")) {
            return mkTextElement(self, posstart);
        } else {
            self.pos = self.pos - 1;
            const elem = mkTextElement(self, posstart);
            self.pos = self.pos + 1;
            return elem;
        }
    } else if (self.getState() == State.inhead1) {
        self.setState(State.leavinghead1);
        const posstart = self.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        self.pos = self.pos + 1;
        return elem;
    } else if (self.getState() == State.inhead2) {
        self.setState(State.leavinghead2);
        const posstart = self.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        self.pos = self.pos + 1;
        return elem;
    } else if (self.getState() == State.inhead3) {
        self.setState(State.leavinghead3);
        const posstart = self.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        self.pos = self.pos + 1;
        return elem;
    } else if (self.getState() == State.inhead4) {
        self.setState(State.leavinghead4);
        const posstart = self.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        self.pos = self.pos + 1;
        return elem;
    } else if (self.getState() == State.inhead5) {
        self.setState(State.leavinghead5);
        const posstart = self.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        self.pos = self.pos + 1;
        return elem;
    } else if (self.getState() == State.inhead6) {
        self.setState(State.leavinghead6);
        const posstart = self.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        self.pos = self.pos + 1;
        return elem;
    } else if (self.getState() == State.inblockquote) {
        self.setState(State.leavingblockquote);
        const posstart = self.pos;
        _ = skipEndOfLine(self);
        const elem = mkTextElement(self, posstart);
        self.pos = self.pos + 1;
        return elem;
    } else if (self.getState() == State.inbold) {
        const posstart = self.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                self.pos = self.pos + 1;
                self.setState(State.leavingbold);
                break;
            } else {
                if (peek(self, "**")) {
                    const elem = mkTextElement(self, posstart);
                    self.pos = self.pos + 2;
                    self.setState(State.leavingbold);
                    return elem;
                }
                self.pos = self.pos + 1;
            }
        }

        const elem = mkTextElement(self, posstart);
        return elem;
    } else if (self.getState() == State.initalic) {
        const posstart = self.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                self.pos = self.pos + 1;
                self.setState(State.leavingitalic);
                break;
            } else {
                if (peek(self, "*")) {
                    const elem = mkTextElement(self, posstart);
                    self.pos = self.pos + 1;
                    self.setState(State.leavingitalic);
                    return elem;
                }
                self.pos = self.pos + 1;
            }
        }

        return mkTextElement(self, posstart);
    } else if (self.getState() == State.inbolditalic) {
        const posstart = self.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                self.pos = self.pos + 1;
                self.setState(State.leavingbolditalic);
                break;
            } else {
                if (peek(self, "***")) {
                    const elem = mkTextElement(self, posstart);
                    self.pos = self.pos + 3;
                    self.setState(State.leavingbolditalic);
                    return elem;
                }
                self.pos = self.pos + 1;
            }
        }

        return mkTextElement(self, posstart);
    } else if (self.getState() == State.incode) {
        const posstart = self.pos;

        while (true) {
            if (skipEndOfLine(self)) {
                self.pos = self.pos + 1;
                self.setState(State.leavingcode);
                break;
            } else {
                //std.debug.print(">>> {s}", .{self.data[self.pos .. self.pos + 2]});
                if (peek(self, "`")) {
                    const elem = mkTextElement(self, posstart);
                    self.pos = self.pos + 1;
                    self.setState(State.leavingcode);
                    return elem;
                }
                self.pos = self.pos + 1;
            }
        }

        return mkTextElement(self, posstart);
    } else if (self.getState() == State.incodeblock) {
        if (eod(self)) {
            self.setState(State.indoc);
            return mkElement(ElemType.endCodeBlock);
        } else if (peek(self, "    ")) {
            self.pos = self.pos + 4;
            const posstart = self.pos;
            skipEndOfLineStrict(self);
            if (!eod(self)) {
                self.pos = self.pos + 1;
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
        return mkElement(ElemType.endBold);
    } else if (self.getState() == State.leavingitalic) {
        _ = try self.popState();
        return mkElement(ElemType.endItalic);
    } else if (self.getState() == State.leavingbolditalic) {
        _ = try self.popState();
        return mkElement(ElemType.endBoldItalic);
    } else if (self.getState() == State.leavingcode) {
        _ = try self.popState();
        return mkElement(ElemType.endCode);
    } else if (self.getState() == State.inlink) {
        self.setState(State.inlinktitle);
        return mkElement(ElemType.startLinkTitle);
    } else if (self.getState() == State.inlinktitle) {
        if (self.data[self.pos] == ']') {
            self.setState(State.leavinglinktitle);
            return mkElement(ElemType.endLinkTitle);
        } else {
            self.pos = self.pos + 1;
            const posstart = self.pos;
            while (self.data[self.pos] != ']') {
                self.pos = self.pos + 1;
            }
            return mkTextElement(self, posstart);
        }
    } else if (self.getState() == State.leavinglinktitle) {
        self.pos = self.pos + 1;
        self.setState(State.inlinkurl);
        return mkElement(ElemType.startLinkUrl);
    } else if (self.getState() == State.inlinkurl) {
        if (self.data[self.pos] == ')') {
            self.setState(State.leavinglink);
            return mkElement(ElemType.endLinkUrl);
        } else {
            self.pos = self.pos + 1;
            const posstart = self.pos;
            while (self.data[self.pos] != ')') {
                self.pos = self.pos + 1;
            }
            return mkTextElement(self, posstart);
        }
    } else if (self.getState() == State.leavinglink) {
        self.pos = self.pos + 1;
        _ = try self.popState();
        return mkElement(ElemType.endLink);
    } else if (self.getState() == State.inshortlink) {
        if (self.data[self.pos] == '>') {
            _ = try self.popState();
            self.pos = self.pos + 1;
            return mkElement(ElemType.endShortLink);
        } else {
            self.pos = self.pos + 1;
            const posstart = self.pos;
            while (self.data[self.pos] != '>') {
                self.pos = self.pos + 1;
            }
            return mkTextElement(self, posstart);
        }
    } else if (self.getState() == State.end) {
        return mkElement(ElemType.endDocument);
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
        .content = self.data[start..self.pos],
    };
}

fn mkLinkElement(_: *Iterator) Element {
    return Element{
        .type = ElemType.link,
    };
}

fn eod(self: *Iterator) bool {
    return self.pos >= self.data.len;
}

fn skipNL(self: *Iterator) void {
    const data = self.data;
    while (self.pos < data.len and (data[self.pos] == '\r' or data[self.pos] == '\n')) {
        self.pos = self.pos + 1;
    }
}

fn skipSpaces(self: *Iterator) void {
    const data = self.data;
    while (self.pos < data.len and (data[self.pos] == ' ' or data[self.pos] == '\t')) {
        self.pos = self.pos + 1;
    }
}

fn skipBytes(self: *Iterator, nbbytes: usize) void {
    for (0..nbbytes) |_| {
        self.pos = self.pos + 1;
    }
}

// parse a paragraph.
// Returns true if the paragraph is completed, false otherwise.
fn parseParagraph(self: *Iterator) bool {
    while (true) {
        if (eod(self)) {
            return true;
        }

        const ch = self.data[self.pos];

        if (ch == '\n') {
            if (self.pos + 1 < self.data.len and (self.data[self.pos + 1] == '\r' or self.data[self.pos + 1] == '\n')) {
                return true;
            }
        }

        if (checkSpecialCharacter(ch)) {
            return false;
        }

        if (trailingWhiteSpace(self, false)) {
            return false;
        }

        self.pos = self.pos + 1;
    }
}

fn trailingWhiteSpace(self: *Iterator, skip: bool) bool {
    var pos = self.pos;
    var nbspaces: usize = 0;
    var nbcr: usize = 0;
    while (pos < self.data.len and (self.data[pos] == ' ' or self.data[pos] == '\r' or self.data[pos] == '\n')) {
        if (self.data[pos] == '\n') {
            nbcr = nbcr + 1;
        }
        if (self.data[pos] == ' ') {
            nbspaces = nbspaces + 1;
        }
        pos = pos + 1;
    }

    const trailing = nbspaces >= 2 and pos < self.data.len and self.data[pos - 1] == '\n' and nbcr == 1;

    if (trailing and skip) {
        self.pos = pos;
    }

    return trailing;
}

fn checkLink(self: *Iterator) bool {
    var pos = self.pos;
    var foundClosingBracket = false;
    var foundClosingParenthese = false;
    if (pos < self.data.len and self.data[pos] == '[') {
        pos = pos + 1;
        while (pos < self.data.len and self.data[pos] != '\n' and self.data[pos] != ']') {
            pos = pos + 1;
        }
        if (pos < self.data.len and self.data[pos] == ']') {
            pos = pos + 1;
            foundClosingBracket = true;
            if (pos < self.data.len and self.data[pos] == '(') {
                pos = pos + 1;
                while (pos < self.data.len and self.data[pos] != '\n' and self.data[pos] != ')') {
                    pos = pos + 1;
                }
                while (pos < self.data.len and self.data[pos] != '\n' and self.data[pos] != ')') {
                    pos = pos + 1;
                }
                if (pos < self.data.len and self.data[pos] == ')') {
                    foundClosingParenthese = true;
                }
            }
        }
    }

    return foundClosingBracket and foundClosingParenthese;
}

fn checkShortLink(self: *Iterator) bool {
    var isurl = false;
    var ismail = false;
    var pos = self.pos;
    if (pos < self.data.len and self.data[pos] == '<') {
        pos = pos + 1;

        while (pos < self.data.len and self.data[pos] != '\n' and self.data[pos] != ' ' and self.data[pos] != '>') {
            if (peekAt(self, "://", pos)) {
                isurl = true;
            }
            if (pos < self.data.len and self.data[pos] == '@') {
                ismail = true;
            }

            pos = pos + 1;
        }
    }

    //std.debug.print("isurl : {any}\n", .{isurl});
    //std.debug.print("ismail : {any}\n", .{ismail});
    //std.debug.print("data : {c}\n", .{self.data[pos]});

    return (isurl or ismail) and pos < self.data.len and self.data[pos] == '>';
}

fn skipEndOfLine(self: *Iterator) bool {
    while (true) {
        if (eod(self)) {
            return true;
        }

        if (self.data[self.pos] == '\n') {
            return true;
        }

        if (self.pos < self.data.len - 1) {
            const ch2 = self.data[self.pos];
            if (checkSpecialCharacter(ch2)) {
                return false;
            }
        }

        self.pos = self.pos + 1;
    }
}

fn skipEndOfLineStrict(self: *Iterator) void {
    while (true) {
        if (eod(self)) {
            return;
        }

        if (self.data[self.pos] == '\n') {
            return;
        }

        self.pos = self.pos + 1;
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

fn checkSpecialCharacter(ch: u8) bool {
    return ch == '*' or ch == '`' or ch == '[' or ch == '<';
}

fn checkIsRule(self: *Iterator) bool {
    const ch = self.data[self.pos];
    var pos: usize = self.pos + 3;
    while (true) {
        const ch2 = self.data[pos];
        if (ch2 == ch) {
            pos = pos + 1;
            continue;
        } else if (ch2 == '\r' or ch2 == '\n') {
            return true;
        } else {
            return false;
        }
    }
}

fn peek(self: *Iterator, prefix: [:0]const u8) bool {
    return peekAt(self, prefix, self.pos);
}

fn peekAt(self: *Iterator, prefix: [:0]const u8, startpos: usize) bool {
    var pos = startpos;
    if (pos + prefix.len >= self.data.len) {
        return false;
    }
    for (prefix) |ch| {
        if (self.data[pos] != ch) {
            return false;
        }
        pos = pos + 1;
    }

    return true;
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
    var it = Iterator{ .data = "<http://goo>" };
    const ok = checkShortLink(&it);
    std.debug.print("is ok ? {any}\n", .{ok});
    try std.testing.expect(ok);

    try showEvents(&it);
}

test "checkshortlink2" {
    var it = Iterator{ .data = "<godybook@example.com>" };
    const ok = checkShortLink(&it);
    std.debug.print("is ok ? {any}\n", .{ok});
    try std.testing.expect(ok);

    try showEvents(&it);
}

fn showEvents(it: *Iterator) !void {
    it.pos = 0;
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
