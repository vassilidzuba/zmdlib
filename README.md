# zmdlib

This repo will hopefully someday contain a markdown parsing library.

The code is distributed under the MIT license.

## Usage

The use of the library is as follows:

- use functions `parse` or `parseFile` to obtain an `Iterator`
- call the iterator to obtain the Elements, and do something with them
- free the iteratore once the work is completed.

Here is a skeleton of the use of the lib/

    const a : std.mem.Allocator = ...;

    var it = try parseFile(ta, "myfile.md");
    defer it.deinit();
    
    while (true) {
        const elem = try next(&it);

        // do something with elem

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

The reference used to the markdeown syntax is <https://www.markdownguide.org/basic-syntax/>.

At the moment, the following markdown tags are supported:

- ordinary paragraphs
- emphasis (bold, italic, bold+italic)
- code and code block (using four spaces)
- linebreak (as trailing spaces)
- headings (level 1 to 6)
- horizontal rule
- blockquotes (partial implementation)
- links and URLs/email addresses
- unordered list (one level°)

warning: UTF-8 is not supported (yet).

# the program tohtml

This program converts a markdown file into an html file.
Use is :

    tohtml [-s | --snippet] [--output OUTPUTFILE] INPUTFILE

The option `-s` / `--snippet` prevents froml outputting the heading tags.

# the program tohtml

This program is a HTTP server allowing to convert markdown text into html file.
To launch it, use :

    tohtmlsrv [[ --port | -p]  PORT]?

The option `-p` / `--port` allows to choose the HTTP port. Ther default is 8080.

The path to be used is `/tohtml`:

    curl -X POST -H 'Content-Type: text/markdown' --data-binary @foo.md  http://localhost:8080/tohtml
    
# build .deb package

To produce a `.deb` package, one need to :

- choose the version number
- change, if needed, the version in :

  - the name of the directory `tohtml_0.0-1`
  - the changelog in `tohtml_0.0-1/DEBIAN/changelog`
  - the control file in `tohtml_0.0-1/DEBIAN/control`

- run (as root) build_deb.sh

Note: you can, of course, build the package when in Debian or a dDebian-based 
distribution, but note that dpkg exists also in Archlinux (for building
packages, not install them !).

## TODO

- add titles to links
- support emphasis over several lines
- normalize spaces
- embedded lists

## Dependencies

- to parse CLI parameters: <https://github.com/vassilidzuba/zcliconfig.git>
- web server: <https://github.com/karlseguin/http.zig>
