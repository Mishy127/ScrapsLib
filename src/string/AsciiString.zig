const std = @import("std");
const ascii = std.ascii;
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;

const AsciiString = @This();
ptr: [*:0]const u8,
len: usize,

pub fn fromSlice(alc: Allocator, string: []const u8) !AsciiString {
    const slice = try alc.dupeZ(u8, string);

    return .{ .ptr = slice.ptr, .len = slice.len };
}

pub fn fromSliceAsLower(alc: Allocator, string: []const u8) !AsciiString {
    const slice = try alc.allocSentinel(u8, string.len, 0);

    for (slice, string) |*t, c|
        t.* = ascii.toLower(c);

    return .{ .ptr = slice.ptr, .len = slice.len };
}

pub fn fromSliceAsUpper(alc: Allocator, string: []const u8) !AsciiString {
    const slice = try alc.allocSentinel(u8, string.len, 0);

    for (slice, string) |*t, c|
        t.* = ascii.toUpper(c);

    return .{ .ptr = slice.ptr, .len = slice.len };
}

pub fn clone(self: AsciiString, alc: Allocator) !AsciiString {
    const string_clone = try alc.dupeZ(u8, self.getBuffer());
    errdefer alc.free(string_clone);

    return .{ .ptr = string_clone.ptr, .len = string_clone.len };
}

pub fn free(self: AsciiString, alc: Allocator) void {
    alc.free(self.getSlice());
}

pub fn getSlice(self: AsciiString) [:0]const u8 {
    return self.ptr[0..self.len :0];
}

pub fn toLower(self: AsciiString, alc: Allocator) !AsciiString {
    const slice = try alc.allocSentinel(u8, self.len, 0);

    for (slice, self.getSlice()) |*t, c|
        t.* = ascii.toLower(c);

    return .{ .ptr = slice.ptr, .len = slice.len };
}

pub fn toUpper(self: AsciiString, alc: Allocator) !AsciiString {
    const slice = try alc.allocSentinel(u8, self.len, 0);

    for (slice, self.getSlice()) |*t, c|
        t.* = ascii.toUpper(c);

    return .{ .ptr = slice.ptr, .len = slice.len };
}

pub fn eql(self: AsciiString, other: AsciiString) bool {
    return mem.eql(u8, self.getSlice(), other.getSlice());
}

pub fn eqlIgnoreCase(self: AsciiString, other: AsciiString) bool {
    return ascii.eqlIgnoreCase(self.getSlice(), other.getSlice());
}

pub fn indexOf(haystack: AsciiString, needle: AsciiString) ?usize {
    return mem.indexOf(u8, haystack.getSlice(), needle.getSlice());
}

pub fn indexOfIgnoreCase(haystack: AsciiString, needle: AsciiString) ?usize {
    return ascii.indexOfIgnoreCase(haystack.getSlice(), needle.getSlice());
}

pub fn indexOfPos(haystack: AsciiString, start_index: usize, needle: AsciiString) ?usize {
    return mem.indexOfPos(u8, haystack.getSlice(), start_index, needle.getSlice());
}

pub fn indexOfPosIgnoreCase(haystack: AsciiString, start_index: usize, needle: AsciiString) ?usize {
    return ascii.indexOfIgnoreCasePos(haystack.getSlice(), start_index, needle.getSlice());
}

pub fn startsWith(haystack: AsciiString, needle: AsciiString) bool {
    return mem.startsWith(u8, haystack.getSlice(), needle.getSlice());
}

pub fn startsWithIgnoreCase(haystack: AsciiString, needle: AsciiString) bool {
    return ascii.startsWithIgnoreCase(haystack.getSlice(), needle.getSlice());
}

pub fn endsWith(haystack: AsciiString, needle: AsciiString) bool {
    return mem.endsWith(u8, haystack.getSlice(), needle.getSlice());
}

pub fn endsWithIgnoreCase(haystack: AsciiString, needle: AsciiString) bool {
    return ascii.endsWithIgnoreCase(haystack.getSlice(), needle.getSlice());
}

pub fn order(self: AsciiString, other: AsciiString) math.Order {
    var a_it = self.iterate();
    var b_it = other.iterate();

    while (true) {
        const a_c = a_it.next() orelse return if (b_it.next()) |_| .lt else .eq;
        const b_c = b_it.next() orelse .gt;

        return math.order(a_c, b_c).differ() orelse continue;
    }
}

pub fn orderIgnoreCase(self: AsciiString, other: AsciiString) math.Order {
    var a_it = self.iterate();
    var b_it = other.iterate();

    while (true) {
        const a_c = a_it.next() orelse return if (b_it.next()) |_| .lt else .eq;
        const b_c = b_it.next() orelse .gt;

        return math.order(ascii.toLower(a_c), ascii.toLower(b_c)).differ() orelse continue;
    }
}

const Iterator = struct {
    buffer: [:0]const u8,
    i: usize = 0,

    pub fn next(self: *Iterator) ?u21 {
        if (self.buffer[self.i] == 0 or self.i >= self.buffer.len)
            return null;

        defer self.i += 1;

        return self.buffer[self.i];
    }

    pub fn nextSlice(self: *Iterator) ?[]const u8 {
        if (self.buffer[self.i] == 0 or self.i >= self.buffer.len)
            return null;

        defer self.i += 1;

        return self.buffer[self.i..][0..1];
    }
};

pub fn iterate(self: AsciiString) Iterator {
    return .{ .buffer = self.getSlice() };
}

pub fn format(
    self: AsciiString,
    comptime fmt: []const u8,
    _: std.fmt.FormatOptions,
    out: anytype,
) !void {
    if (fmt.len == 1 and fmt[0] == 's') {
        var it = self.iterate();
        while (it.nextSlice()) |codepoint_slice|
            try out.writeAll(codepoint_slice);
    } else if (fmt.len == 0) {
        if (self.len == 0)
            return try out.writeAll("{  }");

        var it = self.iterate();

        try out.print("{{ {x:0>2}", .{it.next().?});

        while (it.next()) |codepoint|
            try out.print(", {x:0>2}", .{codepoint});

        try out.writeAll(" }");
    } else @compileError("invalid format '" ++ fmt ++ "' for AsciiString");
}

test "Lower ascii string" {
    const alc = std.testing.allocator;

    const str = try AsciiString.fromSliceAsLower(alc, "VeRy bAdLy cAsEd sTrInG");
    defer str.free(alc);

    try std.testing.expectEqualStrings("very badly cased string", str.getSlice());
}

test "Upper ascii string" {
    const alc = std.testing.allocator;

    const str = try AsciiString.fromSliceAsUpper(alc, "VeRy bAdLy cAsEd sTrInG");
    defer str.free(alc);

    try std.testing.expectEqualStrings("VERY BADLY CASED STRING", str.getSlice());
}
