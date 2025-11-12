const std = @import("std");

const CommandLineParserError = error{
    BadState,
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
    leavingpara,
    leavinghead1,
    leavinghead2,
    leavinghead3,
    leavinghead4,
    leavinghead5,
    leavinghead6,
    end,
};

const ElemType = enum {
    startDocument,
    endDocument,
    startHead1,
    startHead2,
    startHead3,
    startHead4,
    startHead5,
    startHead6,
    endHead1,
    endHead2,
    endHead3,
    endHead4,
    endHead5,
    endHead6,
    startPara,
    endPara,
    text,
    bad,
};

const Element = struct {
    type: ElemType,
    content: ?[]const u8 = null,
};

const Iterator = struct {
    tobefreed: ?[]u8 = null,
    data: []const u8,
    pos: usize = 0,
    state: State = State.start,
};

pub fn parse(text: []const u8) !Iterator {
    std.debug.print("parsing text <\n{s}\n>\n", .{text});
    return Iterator{ .data = text };
}

pub fn parseFile(allocator: std.mem.Allocator, path: [:0]const u8) !Iterator {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    _ = try file.readAll(buffer);

    return Iterator{
        .tobefreed = buffer,
        .data = buffer,
    };
}

fn next(self: *Iterator) !Element {
    if (self.state == State.start) {
        self.*.state = State.indoc;
        return Element{
            .type = ElemType.startDocument,
        };
    } else if (self.state == State.indoc) {
        if (eod(self)) {
            self.state = State.end;
            return Element{
                .type = ElemType.endDocument,
            };
        } else if (self.data[self.pos] == '#') {
            if (peek(self, "######")) {
                self.state = State.inhead6;
                return Element{
                    .type = ElemType.startHead6,
                };
            } else if (peek(self, "#####")) {
                self.state = State.inhead5;
                return Element{
                    .type = ElemType.startHead5,
                };
            } else if (peek(self, "####")) {
                self.state = State.inhead4;
                return Element{
                    .type = ElemType.startHead4,
                };
            } else if (peek(self, "###")) {
                self.state = State.inhead3;
                return Element{
                    .type = ElemType.startHead3,
                };
            } else if (peek(self, "##")) {
                self.state = State.inhead2;
                return Element{
                    .type = ElemType.startHead2,
                };
            } else if (peek(self, "#")) {
                self.state = State.inhead1;
                return Element{
                    .type = ElemType.startHead1,
                };
            } else {
                self.state = State.inpara;
                return Element{
                    .type = ElemType.startPara,
                };
            }
        } else {
            self.state = State.inpara;
            return Element{
                .type = ElemType.startPara,
            };
        }
    } else if (self.state == State.inpara) {
        self.state = State.leavingpara;
        skipNL(self);
        const posstart = self.pos;
        skipEndOfParagraph(self);
        const elem = Element{
            .type = ElemType.text,
            .content = self.data[posstart..self.pos],
        };
        self.pos = self.pos + 1;
        return elem;
    } else if (self.state == State.inhead1) {
        self.state = State.leavinghead1;
        const posstart = self.pos;
        skipEndOfLine(self);
        const elem = Element{
            .type = ElemType.text,
            .content = self.data[posstart..self.pos],
        };
        self.pos = self.pos + 1;
        return elem;
    } else if (self.state == State.inhead2) {
        self.state = State.leavinghead2;
        const posstart = self.pos;
        skipEndOfLine(self);
        const elem = Element{
            .type = ElemType.text,
            .content = self.data[posstart..self.pos],
        };
        self.pos = self.pos + 1;
        return elem;
    } else if (self.state == State.inhead3) {
        self.state = State.leavinghead3;
        const posstart = self.pos;
        skipEndOfLine(self);
        const elem = Element{
            .type = ElemType.text,
            .content = self.data[posstart..self.pos],
        };
        self.pos = self.pos + 1;
        return elem;
    } else if (self.state == State.inhead4) {
        self.state = State.leavinghead4;
        const posstart = self.pos;
        skipEndOfLine(self);
        const elem = Element{
            .type = ElemType.text,
            .content = self.data[posstart..self.pos],
        };
        self.pos = self.pos + 1;
        return elem;
    } else if (self.state == State.inhead5) {
        self.state = State.leavinghead5;
        const posstart = self.pos;
        skipEndOfLine(self);
        const elem = Element{
            .type = ElemType.text,
            .content = self.data[posstart..self.pos],
        };
        self.pos = self.pos + 1;
        return elem;
    } else if (self.state == State.inhead6) {
        self.state = State.leavinghead6;
        const posstart = self.pos;
        skipEndOfLine(self);
        const elem = Element{
            .type = ElemType.text,
            .content = self.data[posstart..self.pos],
        };
        self.pos = self.pos + 1;
        return elem;
    } else if (self.state == State.leavingpara) {
        self.state = State.indoc;
        return Element{
            .type = ElemType.endPara,
        };
    } else if (self.state == State.leavinghead1) {
        self.state = State.indoc;
        return Element{
            .type = ElemType.endHead1,
        };
    } else if (self.state == State.leavinghead2) {
        self.state = State.indoc;
        return Element{
            .type = ElemType.endHead2,
        };
    } else if (self.state == State.leavinghead3) {
        self.state = State.indoc;
        return Element{
            .type = ElemType.endHead3,
        };
    } else if (self.state == State.leavinghead4) {
        self.state = State.indoc;
        return Element{
            .type = ElemType.endHead4,
        };
    } else if (self.state == State.leavinghead5) {
        self.state = State.indoc;
        return Element{
            .type = ElemType.endHead5,
        };
    } else if (self.state == State.leavinghead6) {
        self.state = State.indoc;
        return Element{
            .type = ElemType.endHead6,
        };
    } else if (self.state == State.end) {
        return Element{
            .type = ElemType.endDocument,
        };
    } else {
        return CommandLineParserError.BadState;
    }
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

fn skipEndOfParagraph(self: *Iterator) void {
    while (true) {
        if (eod(self)) {
            return;
        } else if (self.data[self.pos] == '\n') {
            if (self.pos + 1 < self.data.len and (self.data[self.pos + 1] == '\r' or self.data[self.pos + 1] == '\n')) {
                return;
            }
        }
        self.pos = self.pos + 1;
    }
}

fn skipEndOfLine(self: *Iterator) void {
    while (true) {
        if (eod(self)) {
            return;
        } else if (self.data[self.pos] == '\n') {
            return;
        }
        self.pos = self.pos + 1;
    }
}

fn advance(self: *Iterator, nbbytes: usize) bool {
    self.pos = self.pos + nbbytes;
}

fn peek(self: *Iterator, prefix: [:0]const u8) bool {
    if (self.pos + prefix.len >= self.data.len) {
        return false;
    }
    var pos = self.pos;
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

    var it = try parseFile(ta, "testdata/md01.md");
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

    ta.free(it.tobefreed.?);
}
