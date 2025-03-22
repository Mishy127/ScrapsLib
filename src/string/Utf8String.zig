const std = @import("std");
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;

const c_import = @import("../c_import.zig");
const unicode = @import("unicode.zig");

const Utf8String = @This();
ptr: [*:0]u8,
len: usize,

pub fn fromBuffer(alc: Allocator, string: []const u8) !Utf8String {
    const slice = try alc.dupeZ(u8, string);

    return fromOwnedSlice(slice);
}

pub fn fromBufferAsLower(alc: Allocator, string: []const u8) !Utf8String {
    var res: std.ArrayListUnmanaged(u8) = .{};
    defer res.deinit(alc);

    var it: std.unicode.Utf8Iterator = .{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = try unicode.toLowerUtf8(c);

        try res.appendSlice(alc, data[0..len]);
    }

    return fromOwnedSlice(try res.toOwnedSliceSentinel(alc, 0));
}

pub fn fromBufferAsUpper(alc: Allocator, string: []const u8) !Utf8String {
    var res: std.ArrayListUnmanaged(u8) = .{};
    defer res.deinit(alc);

    var it: std.unicode.Utf8Iterator = .{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = try unicode.toUpperUtf8(c);

        try res.appendSlice(alc, data[0..len]);
    }

    return fromOwnedSlice(try res.toOwnedSliceSentinel(alc, 0));
}

pub fn fromOwnedSlice(string: [:0]u8) !Utf8String {
    return .{ .ptr = string.ptr, .len = string.len };
}

pub fn clone(self: Utf8String, alc: Allocator) !Utf8String {
    if (self.len == 0)
        return .{ .ptr = undefined, .len = 0 };

    const slice = try alc.dupeZ(u8, self.getSlice());
    errdefer alc.free(slice);

    return fromOwnedSlice(slice);
}

pub fn free(self: Utf8String, alc: Allocator) void {
    if (self.len != 0)
        alc.free(self.ptr[0..self.len :0]);
}

pub fn getSlice(self: Utf8String) []u8 {
    return self.ptr[0..self.len];
}

pub fn toLower(self: Utf8String, alc: Allocator) !Utf8String {
    var res: std.ArrayListUnmanaged(u8) = .{};
    defer res.deinit(alc);

    var it = std.unicode.Utf8Iterator{ .bytes = self.getSlice(), .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = try unicode.encodeUtf8ToLower(c);

        try res.appendSlice(alc, data[0..len]);
    }

    return fromOwnedSlice(try res.toOwnedSliceSentinel(alc, 0));
}

pub fn toUpper(self: Utf8String, alc: Allocator) !Utf8String {
    var res: std.ArrayListUnmanaged(u8) = .{};
    defer res.deinit(alc);

    var it = std.unicode.Utf8Iterator{ .bytes = self.getSlice(), .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = try unicode.encodeUtf8ToUpper(c);

        try res.appendSlice(alc, data[0..len]);
    }

    return fromOwnedSlice(try res.toOwnedSliceSentinel(alc, 0));
}

pub fn commonStart(self: Utf8String, other: Utf8String) usize {
    if (self.ptr == other.ptr)
        return @min(self.len, other.len);

    var i: usize = 0;
    while (true) {
        var a_it: std.unicode.Utf8Iterator = .{ .bytes = self.getSlice(), .i = i };
        var b_it: std.unicode.Utf8Iterator = .{ .bytes = other.getSlice(), .i = i };

        const a_c = a_it.nextCodepoint() orelse return self.len;
        const b_c = b_it.nextCodepoint() orelse return other.len;

        if (a_c != b_c)
            return i;

        i = a_it.i;
    }
}

pub fn commonStartIgnoreCase(self: Utf8String, other: Utf8String) !usize {
    if (self.ptr == other.ptr)
        return @min(self.len, other.len);

    var i: usize = 0;
    while (true) {
        var a_it: std.unicode.Utf8Iterator = .{ .bytes = self.getSlice(), .i = i };
        var b_it: std.unicode.Utf8Iterator = .{ .bytes = other.getSlice(), .i = i };

        const a_c = a_it.nextCodepoint() orelse return self.len;
        const b_c = b_it.nextCodepoint() orelse return other.len;

        if (try unicode.toLower(a_c) != try unicode.toLower(b_c))
            return i;

        i = a_it.i;
    }
}

pub fn commonEnd(haystack: Utf8String, needle: Utf8String) usize {
    _ = haystack;
    _ = needle;

    return 0;
}

pub fn commonEndIgnoreCase(haystack: Utf8String, needle: Utf8String) usize {
    _ = haystack;
    _ = needle;

    return 0;
}

pub fn eql(self: Utf8String, other: Utf8String) bool {
    if (self.len != other.len)
        return false;

    if (self.ptr == other.ptr)
        return true;

    var a_it: std.unicode.Utf8Iterator = .{ .bytes = self.getSlice(), .i = 0 };
    var b_it: std.unicode.Utf8Iterator = .{ .bytes = other.getSlice(), .i = 0 };
    while (true) {
        const a_c = a_it.nextCodepoint() orelse return if (b_it.nextCodepoint()) |_| false else true;
        const b_c = b_it.nextCodepoint() orelse return false;

        if (a_c != b_c)
            return false;
    }
}

pub fn eqlIgnoreCase(self: Utf8String, other: Utf8String) !bool {
    if (self.len != other.len)
        return false;

    if (self.ptr == other.ptr)
        return true;

    var a_it: std.unicode.Utf8Iterator = .{ .bytes = self.getSlice(), .i = 0 };
    var b_it: std.unicode.Utf8Iterator = .{ .bytes = other.getSlice(), .i = 0 };
    while (true) {
        const a_c = a_it.nextCodepoint() orelse return if (b_it.nextCodepoint()) |_| false else true;
        const b_c = b_it.nextCodepoint() orelse return false;

        if (try unicode.toLower(a_c) != try unicode.toLower(b_c))
            return false;
    }
}

pub fn indexOf(haystack: Utf8String, needle: Utf8String) ?usize {
    _ = haystack;
    _ = needle;
}

pub fn indexOfIgnoreCase(haystack: Utf8String, needle: Utf8String) ?usize {
    _ = haystack;
    _ = needle;

    return false;
}

pub fn startsWith(haystack: Utf8String, needle: Utf8String) bool {
    if (haystack.ptr == needle.ptr)
        return @min(haystack.len, needle.len);

    var a_it: std.unicode.Utf8Iterator = .{ .bytes = haystack.getSlice(), .i = 0 };
    var b_it: std.unicode.Utf8Iterator = .{ .bytes = needle.getSlice(), .i = 0 };
    while (true) {
        const a_c = a_it.nextCodepoint() orelse return false;
        const b_c = b_it.nextCodepoint() orelse return true;

        if (a_c != b_c)
            return false;
    }
}

pub fn startsWithIgnoreCase(haystack: Utf8String, needle: Utf8String) bool {
    if (haystack.ptr == needle.ptr)
        return @min(haystack.len, needle.len);

    var a_it: std.unicode.Utf8Iterator = .{ .bytes = haystack.getSlice(), .i = 0 };
    var b_it: std.unicode.Utf8Iterator = .{ .bytes = needle.getSlice(), .i = 0 };
    while (true) {
        const a_c = a_it.nextCodepoint() orelse return false;
        const b_c = b_it.nextCodepoint() orelse return true;

        if (try unicode.toLower(a_c) != try unicode.toLower(b_c))
            return false;
    }
}

pub fn endsWith(haystack: Utf8String, needle: Utf8String) bool {
    _ = haystack;
    _ = needle;

    return false;
}

pub fn endsWithIgnoreCase(haystack: Utf8String, needle: Utf8String) bool {
    _ = haystack;
    _ = needle;

    return false;
}

pub fn order(self: Utf8String, other: Utf8String) math.Order {
    var a_it: std.unicode.Utf8Iterator = .{ .bytes = self.getSlice(), .i = 0 };
    var b_it: std.unicode.Utf8Iterator = .{ .bytes = other.getSlice(), .i = 0 };

    while (true) {
        const a_c = a_it.nextCodepoint() orelse return if (b_it.nextCodepoint()) |_| .lt else .eq;
        const b_c = b_it.nextCodepoint() orelse return .gt;

        return math.order(a_c, b_c).differ() orelse continue;
    }
}

pub fn orderIgnoreCase(self: Utf8String, other: Utf8String) !math.Order {
    var a_it: std.unicode.Utf8Iterator = .{ .bytes = self.getSlice(), .i = 0 };
    var b_it: std.unicode.Utf8Iterator = .{ .bytes = other.getSlice(), .i = 0 };

    while (true) {
        const a_c = a_it.nextCodepoint() orelse return if (b_it.nextCodepoint()) |_| .lt else .eq;
        const b_c = b_it.nextCodepoint() orelse return .gt;

        return math.order(try unicode.toLower(a_c), try unicode.toLower(b_c)).differ() orelse continue;
    }
}
