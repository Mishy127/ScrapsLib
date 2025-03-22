const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

pub const BitList = struct {
    items: []u8,
    len: usize,

    pub fn initCapacity(alc: Allocator, size: usize) !BitList {
        const buffer = try alc.alloc(u8, math.divCeil(usize, size, 8) catch unreachable);

        @memset(buffer, 0);

        return .{
            .items = buffer,
            .len = size,
        };
    }

    pub fn deinit(self: *BitList, alc: Allocator) void {
        alc.free(self.items);
    }

    pub fn at(self: *const BitList, i: usize) bool {
        std.debug.assert(i < self.len);

        const sup = @divFloor(i, 8);
        const sub: u3 = @intCast(i % 8);

        return (self.items[sup] & (@as(u8, 1) << sub)) != 0;
    }

    pub fn on(self: *BitList, i: usize) void {
        std.debug.assert(i < self.len);

        const sup = @divFloor(i, 8);
        const sub: u3 = @intCast(i % 8);

        self.items[sup] &= @as(u8, 1) << sub;
    }

    pub fn off(self: *BitList, i: usize) void {
        std.debug.assert(i < self.len);

        const sup = @divFloor(i, 8);
        const sub: u3 = @intCast(i % 8);

        self.items[sup] -= self.items[sup] & (@as(u8, 1) << sub);
    }

    pub fn bitAnd(self: BitList, alc: Allocator, other: BitList) !BitList {
        const new_list = try BitList.initCapacity(alc, @max(self.len, other.len));

        for (0..@min(self.len, other.len)) |i| {
            if (self.at(i) and other.at(i))
                new_list.on(i);
        }

        return new_list;
    }

    pub fn bitOr(self: BitList, alc: Allocator, other: BitList) !BitList {
        const new_list = try BitList.initCapacity(alc, @max(self.len, other.len));

        for (0..@max(self.len, other.len)) |i| {
            const a = if (i < self.len) self.at(i) else false;
            const b = if (i < other.len) other.at(i) else false;

            if (a or b)
                new_list.on(i);
        }

        return new_list;
    }

    pub fn mergeAnd(self: *BitList, other: BitList) void {
        for (0..@min(self.len, other.len)) |i| {
            if (self.at(i) or other.at(i))
                self.on(i);
        }
    }

    pub fn mergeOr(self: *BitList, other: BitList) void {
        for (0..@min(self.len, other.len)) |i| {
            if (self.at(i) or other.at(i))
                self.on(i);
        }
    }
};
