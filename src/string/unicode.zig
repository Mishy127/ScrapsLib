const std = @import("std");
const Allocator = std.mem.Allocator;
const unicode = std.unicode;
const assert = std.debug.assert;

const c_import = @import("../c_import.zig");

pub fn toLower(c: u21) !u21 {
    var err: c_import.UErrorCode = c_import.U_ZERO_ERROR;

    const utf16_data, const utf16_len = try encodeUtf16Le(c);

    var out = [_]u16{0} ** 2;
    const ilen = c_import.u_strToLower_70(
        &out,
        out.len,
        &utf16_data,
        utf16_len,
        null,
        &err,
    );

    if (c_import.U_FAILURE(err))
        return error.Failure;
    const len: usize = @intCast(ilen);

    if (len == 2) {
        assert(unicode.utf16IsHighSurrogate(out[0]));
        assert(unicode.utf16IsLowSurrogate(out[1]));

        return unicode.utf16DecodeSurrogatePair(out[0..2]);
    } else {
        return out[0];
    }
}

pub fn toUpper(c: u21) !u21 {
    var err: c_import.UErrorCode = c_import.U_ZERO_ERROR;

    const utf16_data, const utf16_len = try encodeUtf16Le(c);

    var out = [_]u16{0} ** 2;
    const ilen = c_import.u_strToUpper_70(
        &out,
        out.len,
        &utf16_data,
        utf16_len,
        null,
        &err,
    );

    if (c_import.U_FAILURE(err))
        return error.Failure;
    const len: usize = @intCast(ilen);

    if (len == 2) {
        assert(unicode.utf16IsHighSurrogate(out[0]));
        assert(unicode.utf16IsLowSurrogate(out[1]));

        return unicode.utf16DecodeSurrogatePair(out[0..2]);
    } else {
        return out[0];
    }
}

test "Unicode casing" {
    try std.testing.expectEqual('a', try toLower('A'));
    try std.testing.expectEqual('B', try toUpper('b'));
    try std.testing.expectEqual('ñ', try toLower('Ñ'));
    try std.testing.expectEqual(try toLower('.'), try toUpper('.'));
}

pub fn encodeUtf8(c: u21) !struct { [4]u8, u3 } {
    var data = [_]u8{0} ** 4;

    const len: u3 = @intCast(try unicode.utf8Encode(c, &data));

    return .{ data, len };
}

pub fn encodeUtf8ToLower(c: u21) !struct { [4]u8, u3 } {
    return try encodeUtf8(try toLower(c));
}

pub fn encodeUtf8ToUpper(c: u21) !struct { [4]u8, u3 } {
    return try encodeUtf8(try toUpper(c));
}

pub fn encodeUtf16Le(c: u21) !struct { [2]u16, u2 } {
    const utf8_data, const utf8_len = try encodeUtf8(c);
    const utf8_slicer = utf8_data[0..utf8_len];

    var data = [_]u16{0} ** 2;

    const len: u2 = @intCast(try unicode.utf8ToUtf16Le(&data, utf8_slicer));

    return .{ data, len };
}

pub fn encodeUtf16LeToLower(c: u21) !struct { [2]u16, u2 } {
    return encodeUtf16Le(try toLower(c));
}

pub fn encodeUtf16LeToUpper(c: u21) !struct { [2]u16, u2 } {
    return encodeUtf16Le(try toUpper(c));
}

///Clones a string
pub fn clone(alc: Allocator, string: []const u8) ![]const u8 {
    return alc.dupe(u8, string);
}

pub fn cloneSentinel(alc: Allocator, string: []const u8) ![:0]const u8 {
    return alc.dupeZ(u8, string);
}

pub fn cloneSentinelOrNull(alc: Allocator, string: []const u8) !?[:0]const u8 {
    if (string.len == 0)
        return null;

    return try alc.dupeZ(u8, string);
}

///Clones and tranforms the string to uppercase
pub fn cloneToLower(alc: Allocator, string: []const u8) ![]const u8 {
    var res: std.ArrayListUnmanaged(u8) = .{};
    defer res.deinit(alc);

    var it = std.unicode.Utf8Iterator{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = try encodeUtf8ToLower(c);

        try res.appendSlice(alc, data[0..len]);
    }

    return res.toOwnedSlice(alc);
}

///Clones and tranforms the string to uppercase and adding a null terminator
pub fn cloneToLowerSentinel(alc: Allocator, string: []const u8) ![:0]const u8 {
    var res: std.ArrayListUnmanaged(u8) = .{};
    defer res.deinit(alc);

    var it = std.unicode.Utf8Iterator{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = try encodeUtf8ToLower(c);

        try res.appendSlice(alc, data[0..len]);
    }

    return res.toOwnedSliceSentinel(alc, 0);
}

///Clones and tranforms the string to lowercase
pub fn cloneToUpper(alc: Allocator, string: []const u8) ![]const u8 {
    var res: std.ArrayListUnmanaged(u8) = .{};
    defer res.deinit(alc);

    var it = std.unicode.Utf8Iterator{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = try encodeUtf8ToUpper(c);

        try res.appendSlice(alc, data[0..len]);
    }

    return res.toOwnedSlice(alc);
}

///Clones and tranforms the string to lowercase and adding a null terminator
pub fn cloneToUpperSentinel(alc: Allocator, string: []const u8) ![:0]const u8 {
    var res: std.ArrayListUnmanaged(u8) = .{};
    defer res.deinit(alc);

    var it = std.unicode.Utf8Iterator{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = try encodeUtf8ToUpper(c);

        try res.appendSlice(alc, data[0..len]);
    }

    return res.toOwnedSliceSentinel(alc, 0);
}

pub fn calcUtf8toUtf16Le(string: []const u8) !usize {
    var size: usize = 0;

    var it: unicode.Utf8Iterator = .{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        _, const len = try encodeUtf16Le(c);

        size += len;
    }

    return size;
}

pub fn utf8ToUtf16Le(out: []u16, string: []const u8) !usize {
    var i: usize = 0;

    var it: unicode.Utf8Iterator = .{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = encodeUtf16Le(c);

        @memcpy(out[i..][0..len], data[0..len]);

        i += len;
    }

    return i;
}

pub fn utf8ToUtf16LeToLower(out: []u16, string: []const u8) !usize {
    var i: usize = 0;

    var it: unicode.Utf8Iterator = .{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = encodeUtf16LeToLower(c);

        @memcpy(out[i..][0..len], data[0..len]);

        i += len;
    }

    return i;
}

pub fn utf8ToUtf16LeToUpper(out: []u16, string: []const u8) !usize {
    var i: usize = 0;

    var it: unicode.Utf8Iterator = .{ .bytes = string, .i = 0 };
    while (it.nextCodepoint()) |c| {
        const data, const len = encodeUtf16LeToUpper(c);

        @memcpy(out[i..][0..len], data[0..len]);

        i += len;
    }

    return i;
}

pub fn utf8toUtf16LeAlloc(alc: Allocator, string: []const u8) ![]const u16 {
    const size = try calcUtf8toUtf16Le(string);

    var res = try alc.alloc(u16, size);

    assert(size == try utf8ToUtf16Le(&res, string));

    return res;
}

pub fn utf8ToUtf16LeAllocSentinel(alc: Allocator, string: []const u8) ![:0]const u16 {
    const size = try calcUtf8toUtf16Le(string);

    var res = try alc.allocSentinel(u16, size, 0);

    assert(size == try utf8ToUtf16Le(&res, string));

    return res;
}

test "Unicode String" {
    const alc = std.testing.allocator;

    const str = "Hello world! ÑÑÑ ĉ";

    const lower = try cloneToLower(alc, str);
    defer alc.free(lower);

    try std.testing.expectEqualStrings("hello world! ñññ ĉ", lower);

    const upper = try cloneToUpper(alc, str);
    defer alc.free(upper);

    try std.testing.expectEqualStrings("HELLO WORLD! ÑÑÑ Ĉ", upper);
}

pub fn order(a: []const u8, b: []const u8) std.math.Order {
    var a_it: std.unicode.Utf8Iterator = .{ .bytes = a, .i = 0 };
    var b_it: std.unicode.Utf8Iterator = .{ .bytes = b, .i = 0 };

    while (true) {
        const a_c = a_it.nextCodepoint() orelse return if (b_it.nextCodepoint()) |_| .lt else .eq;
        const b_c = b_it.nextCodepoint() orelse return .gt;

        return std.math.order(a_c, b_c).differ() orelse continue;
    }
}

pub fn orderIgnoreCase(a: []const u8, b: []const u8) !std.math.Order {
    var a_it: std.unicode.Utf8Iterator = .{ .bytes = a, .i = 0 };
    var b_it: std.unicode.Utf8Iterator = .{ .bytes = b, .i = 0 };

    while (true) {
        const a_c = a_it.nextCodepoint() orelse return if (b_it.nextCodepoint()) |_| .lt else .eq;
        const b_c = b_it.nextCodepoint() orelse return .gt;

        return std.math.order(try unicode.toLower(a_c), try unicode.toLower(b_c)).differ() orelse continue;
    }
}
