# zmdlib

This repo will hopefully someday contain a markdown parsing library.

The code is distributed under the MIT license.

## Usage

The use of the library is as follows:

- use functions `parse` or `parseFile` to obtain an `Iterator`
- call the iterator to obtain the Elements, and do something with them
- free the iteratore once the work is completed

    const a : std.mem.Allocator = ...;

    var it = try parseFile(ta, "myfile.md");
    defer it.deinit();
    
    while (true) {
        const elem = try next(&it);

        // do somthing with elem

        if (elem.type == ElemType.endDocument) {
            break;
        }
    }

For each structure (e.g. a heading), one will get three elements :

- start of the structure
- textual data
- end of the structure

The Element is declared as such :

    const Element = struct {
        type: ElemType,
        content: ?[]const u8 = null,
    };

where `ElemType` is an `enum` (look the source for details).

## Functionnalities

The reference used to the markdeown syntax is [https://www.markdownguide.org/basic-syntax/](https://www.markdownguide.org/basic-syntax/).

At the moment, the following markdown tags are supported:

- ordinary paragraphs
- headings (level 1 to 6)
- blockquotes (partial implementation)
- emphasis (bold, italic, bold+italic)
- code and code block (using four spaces)
- horizontal rule
- linebrak (as trailing spaces)

warning: UTF-8 is not supported (yet).

# the program tohtml

This program converts a markdown file into an html file.
