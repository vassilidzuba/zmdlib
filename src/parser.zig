const std = @import("std");

const State = enum {
    start,
    indoc,
    inhead1,
    inhead3,
    inpara,
    end,
};

const ElemType = enum {
    startDocument,
    endDocument,
    startHead1,
    endHead1,
    startHead2,
    endHead2,
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
        } else {
            const elem = Element{
                .type = ElemType.text,
                .content = self.data[self.pos .. self.pos + 1],
            };
            self.pos = self.pos + 1;
            return elem;
        }
    } else if (self.state == State.end) {
        return Element{
            .type = ElemType.endDocument,
        };
    } else {
        return Element{
            .type = ElemType.bad,
        };
    }
}

fn eod(self: *Iterator) bool {
    return self.pos >= self.data.len;
}

fn advance(self: *Iterator, nbbytes: usize) bool {
    self.pos = self.pos + nbbytes;
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
            std.debug.print(": {s}", .{content});
        }

        std.debug.print("\n", .{});

        if (elem.type == ElemType.endDocument) {
            break;
        }
    }

    ta.free(it.tobefreed.?);
}
