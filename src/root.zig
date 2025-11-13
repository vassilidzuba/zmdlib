//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const parser = @import("./parser.zig");
const md2html = @import("./md2html.zig");

pub const Parser = parser.Parser;
pub const Iterator = parser.Iterator;
pub const Element = parser.Element;
pub const ElementType = parser.ElementType;

pub const md2htmlFile = md2html.md2htmlFile;
