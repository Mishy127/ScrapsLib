const std = @import("std");
const math = std.math;
const mem = std.mem;

const unicode = @import("string/unicode.zig");

pub fn asc(comptime T: type) fn (void, T, T) math.Order {
    return struct {
        fn order(_: void, a: T, b: T) math.Order {
            return math.order(a, b);
        }
    }.order;
}

pub fn desc(comptime T: type) fn (void, T, T) math.Order {
    return struct {
        fn order(_: void, a: T, b: T) math.Order {
            return math.order(a, b).invert();
        }
    }.order;
}

pub fn ascString(_: void, a: []const u8, b: []const u8) math.Order {
    return unicode.order(a, b);
}

pub fn descString(_: void, a: []const u8, b: []const u8) math.Order {
    return unicode.order(a, b).invert();
}

pub fn ascStringIgnoreCase(_: void, a: []const u8, b: []const u8) !math.Order {
    return unicode.orderIgnoreCase(a, b);
}

pub fn descStringIgnoreCase(_: void, a: []const u8, b: []const u8) !math.Order {
    return (try unicode.orderIgnoreCase(a, b)).invert();
}
