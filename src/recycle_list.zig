const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

pub fn RecycleList(comptime T: type) type {
    return struct {
        const Self = @This();
        items: []T = &.{},
        capacity: usize = 0,
        holes: []u64 = &.{},

        pub fn initCapacity(alc: Allocator, len: usize) !Self {
            var self = Self{};

            try self.resizeAllocatedSlice(alc, len);

            return self;
        }

        pub fn deinit(self: Self, alc: Allocator) void {
            alc.free(self.getAllocatedSlice());
            alc.free(self.holes);
        }

        pub fn getAllocatedSlice(self: Self) []T {
            return self.items.ptr[0..self.capacity];
        }

        pub fn insert(self: *Self, alc: Allocator, item: T) !usize {
            if (self.getFirstEmpty()) |empty| {
                self.items[empty] = item;
                self.setUsed(empty);

                return empty;
            }

            try self.ensureUnusedCapacity(alc, 1);

            const i = self.items.len;

            self.items.len += 1;
            self.items[i] = item;
            self.setUsed(i);

            return i;
        }

        pub fn insertAssumeCapacity(self: *Self, item: T) usize {
            if (self.getFirstEmpty()) |empty| {
                self.items[empty] = item;
                self.setUsed(empty);

                return empty;
            }
            std.debug.assert(self.items.len != self.capacity);

            const i = self.items.len;

            self.items.len += 1;
            self.items[i] = item;
            self.setUsed(i);

            return i;
        }

        pub fn insertSlice(self: *Self, alc: Allocator, items: []const T) !void {
            const excess_i = for (items, 0..) |item, i| {
                if (self.getFirstEmpty()) |empty| {
                    self.items[empty] = item;
                    self.setUsed(empty);
                } else break i;
            } else return;
            const excess = items[excess_i..];

            try self.ensureUnusedCapacity(alc, excess.len);

            const i = self.items.len;
            self.items.len += excess.len;

            @memcpy(self.items[i..][0..excess.len], excess);
            self.setManyUsed(i, i + excess.len);
        }

        pub fn insertSliceAssumeCapacity(self: *Self, items: []const T) void {
            const excess_i = for (items, 0..) |item, i| {
                if (self.getFirstEmpty()) |empty| {
                    self.items[empty] = item;
                    self.setUsed(empty);
                } else break i;
            } else return;
            const excess = items[excess_i..];

            std.debug.assert(self.items.len + excess.len <= self.capacity);

            const i = self.items.len;
            self.items.len += excess.len;

            @memcpy(self.items[i..][0..excess.len], excess);
            self.setManyUsed(i, i + excess.len);
        }

        pub fn addOne(self: *Self, alc: Allocator) Allocator.Error!usize {
            if (self.getFirstEmpty()) |empty| {
                self.setUsed(empty);

                return empty;
            }

            try self.ensureUnusedCapacity(alc, 1);

            const i = self.items.len;

            self.items.len += 1;
            self.setUsed(i);

            return i;
        }

        pub fn addOneAssumeCapacity(self: *Self) usize {
            if (self.getFirstEmpty()) |empty| {
                self.setUsed(empty);

                return empty;
            }

            std.debug.assert(self.items.len != self.capacity);

            const i = self.items.len;

            self.items.len += 1;
            self.setUsed(i);

            return i;
        }

        pub fn remove(self: *Self, i: usize) T {
            const item: T = self.items[i];

            self.items[i] = undefined;
            self.setUnused(i);

            if (i == self.items.len - 1)
                self.trimTail();

            return item;
        }

        pub fn ensureUnusedCapacity(self: *Self, alc: Allocator, len: usize) !void {
            return self.ensureTotalCapacity(alc, std.math.add(usize, self.items.len, len) catch return error.OutOfMemory);
        }

        pub fn ensureTotalCapacity(self: *Self, alc: Allocator, len: usize) !void {
            if (self.capacity >= len)
                return;

            const better_capacity = growCapacity(self.capacity, len);

            try self.resizeAllocatedSlice(alc, better_capacity);
        }

        pub fn isEmpty(self: Self, i: usize) bool {
            const slot_i = i / 64;
            const sub_i: u6 = @intCast(i % 64);

            return (self.holes[slot_i] & (@as(u64, 1) << sub_i)) != 0;
        }

        pub fn getFirstEmpty(self: Self) ?usize {
            return for (self.holes, 0..) |slots, i| {
                const first_empty = @ctz(slots);

                if (first_empty == 64)
                    continue;

                const j = i * 64 + first_empty;

                break if (j >= self.items.len) null else j;
            } else null;
        }

        fn resizeAllocatedSlice(self: *Self, alc: Allocator, new_len: usize) !void {
            const holes_new_len = math.divCeil(u64, new_len, 64) catch unreachable;

            if (alc.resize(self.holes, holes_new_len)) {
                const shortest = @min(self.holes.len, holes_new_len);

                self.holes.len = holes_new_len;

                @memset(self.holes[shortest..], math.maxInt(u64));
            } else {
                const shortest = @min(self.holes.len, holes_new_len);
                const new_slice = try alc.alloc(u64, holes_new_len);

                @memcpy(new_slice[0..shortest], self.holes[0..shortest]);
                @memset(new_slice[shortest..], math.maxInt(u64));

                alc.free(self.holes);

                self.holes = new_slice;
            }

            const slice = self.getAllocatedSlice();

            if (alc.resize(slice, new_len)) {
                self.capacity = new_len;
            } else {
                const shortest = @min(slice.len, new_len);
                const new_slice = try alc.alloc(T, new_len);

                @memcpy(new_slice[0..shortest], slice[0..shortest]);
                @memset(new_slice[shortest..], undefined);

                self.items = new_slice[0..self.items.len];
                self.capacity = new_len;

                alc.free(slice);
            }
        }

        fn trimTail(self: *Self) void {
            for (0..self.holes.len) |i| {
                const j = self.holes.len - (i + 1);

                const leading = @clz(~self.holes[j]);

                if (leading == 64) {
                    if (j == 0) {
                        self.items.len = 0;

                        return;
                    } else continue;
                }

                self.items.len = j * 64 + (64 - leading);
                return;
            }
        }

        pub fn setUnused(self: *Self, i: usize) void {
            const slot_i = i / 64;
            const sub_i: u6 = @intCast(i % 64);

            self.holes[slot_i] |= @as(u64, 1) << sub_i;
        }

        pub fn setUsed(self: *Self, i: usize) void {
            const slot_i = i / 64;
            const sub_i: u6 = @intCast(i % 64);

            self.holes[slot_i] -= self.holes[slot_i] & (@as(u64, 1) << sub_i);
        }

        fn setManyUsed(self: *Self, start: usize, end: usize) void {
            if (start == end)
                return;

            if (@divFloor(start, 64) == @divFloor(end, 64)) {
                const slot_i = start / 64;

                var mask: u64 = 0;
                for (start..end) |i|
                    mask |= @as(u64, 1) << @intCast(i % 64);

                std.debug.assert((self.holes[slot_i] & mask) == mask);

                self.holes[slot_i] -= mask;

                return;
            }

            {
                const slot_i = start / 64;
                const start_i = start % 64;

                if (start_i != 0) {
                    var mask: u64 = 0;
                    for (start_i..64) |sub_i|
                        mask |= @as(u64, 1) << @intCast(sub_i);

                    const value = (self.holes[slot_i] & mask);

                    std.debug.assert(value == mask);

                    self.holes[slot_i] -= mask;
                }
            }

            const bulk_start = math.divCeil(usize, start, 64) catch unreachable;
            const bulk_end = @divFloor(end, 64);

            @memset(self.holes[bulk_start..bulk_end], 0);

            {
                const slot_i = end / 64;
                const end_i = end % 64;

                var mask: u64 = 0;
                for (0..end_i) |sub_i|
                    mask |= @as(u64, 1) << @intCast(sub_i);

                std.debug.assert(self.holes[slot_i] & mask == mask);

                self.holes[slot_i] -= mask;
            }
        }
    };
}

fn growCapacity(current: usize, minimum: usize) usize {
    var new = current;
    return while (true) {
        new +|= new / 2 + 8;

        if (new >= minimum)
            break new;
    };
}

test "Test recycling list" {
    const alc = std.testing.allocator;

    var list = RecycleList(u32){};
    defer list.deinit(alc);

    for (0..55) |i|
        try list.insertSlice(alc, &(std.simd.iota(u32, 55) + @as(@Vector(55, u32), @splat(@intCast(i * 55)))));

    for (3..(55 * 55)) |i|
        std.debug.assert(list.remove(i) == i);

    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 1, 2 }, list.items);
}
