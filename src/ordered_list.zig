const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

///A lists that keeps all of it's items ordered at any moment
///Adapts return of most methods if the order function returns an error union
pub fn OrderedList(comptime T: type, comptime orderFn: anytype) type {
    const fn_info: std.builtin.Type.Fn = @typeInfo(@TypeOf(orderFn)).Fn;
    const Context: type = fn_info.params[0].type.?;

    const ret_info: std.builtin.Type = @typeInfo(fn_info.return_type.?);
    const returns_error = ret_info == .ErrorUnion;

    return struct {
        const Self = @This();
        items: []T = &.{},
        capacity: usize = 0,

        pub fn initCapacity(alc: Allocator, len: usize) !Self {
            var self: Self = .{};

            try self.resizeAllocatedSlice(alc, len);

            return self;
        }

        pub fn deinit(self: Self, alc: Allocator) void {
            alc.free(self.getAllocatedSlice());
        }

        ///Creates a new list with a different sorting function
        pub fn rearrange(self: Self, alc: Allocator, comptime newOrderFn: anytype, context: anytype) OrderedList(T, newOrderFn).OrderFnError(Allocator.Error!OrderedList(T, newOrderFn)) {
            const NewList = OrderedList(T, newOrderFn);
            var other = try NewList.initCapacity(alc, self.items.len);

            if (NewList.OrderFnErrorSet()) |_|
                try other.insertSliceAssumeCapacity(context, self.items)
            else
                other.insertSliceAssumeCapacity(context, self.items);

            return other;
        }

        pub fn getAllocatedSlice(self: Self) []T {
            return self.items.ptr[0..self.capacity];
        }

        pub fn insert(self: *Self, alc: Allocator, context: Context, item: T) OrderFnError(Allocator.Error!usize) {
            try self.ensureUnusedCapacity(alc, 1);

            const pos = if (returns_error) try self.getItemPosition(context, item) else self.getItemPosition(context, item);

            if (pos.found_existing)
                return pos.index;

            self.insertAt(pos.index, item);

            return pos.index;
        }

        pub fn insertAssumeCapacity(self: *Self, context: Context, item: T) OrderFnError(usize) {
            std.debug.assert(self.items.len != self.capacity);

            const pos = if (returns_error) try self.getItemPosition(context, item) else self.getItemPosition(context, item);

            if (pos.found_existing)
                return pos.index;

            self.insertAt(pos.index, item);

            return pos.index;
        }

        pub fn insertSlice(self: *Self, alc: Allocator, context: Context, items: []const T) OrderFnError(Allocator.Error!void) {
            try self.ensureUnusedCapacity(alc, items.len);

            for (items) |item| {
                const pos = if (returns_error) try self.getItemPosition(context, item) else self.getItemPosition(context, item);

                if (pos.found_existing)
                    continue;

                self.insertAt(pos.index, item);
            }
        }

        pub fn insertSliceAssumeCapacity(self: *Self, context: Context, items: []const T) OrderFnError(void) {
            std.debug.assert(self.items.len + items.len <= self.capacity);

            for (items) |item| {
                const pos = if (returns_error) try self.getItemPosition(context, item) else self.getItemPosition(context, item);

                if (pos.found_existing)
                    continue;

                self.insertAt(pos.index, item);
            }
        }

        pub fn remove(self: *Self, context: Context, item: T) OrderFnError(T) {
            const pos = if (returns_error) try self.getItemPosition(context, item) else self.getItemPosition(context, item);

            if (!pos.found_existing)
                return item;

            return removeAt(self, pos.index);
        }

        pub const ItemPosition = struct {
            found_existing: bool,
            index: usize,
        };

        pub fn getItemPosition(self: Self, context: Context, item: T) OrderFnError(ItemPosition) {
            var start: usize = 0;
            var end: usize = self.items.len;

            while (start != end) {
                const j = start + @divFloor(end - start, 2);

                // simple binary search implementation
                switch (order(context, item, self.items[j]) catch |err| return err) {
                    .gt => {
                        start = j + 1;
                    },
                    .lt => {
                        end = j;
                    },
                    .eq => return .{ .found_existing = true, .index = j },
                }
            }

            return .{ .found_existing = false, .index = end };
        }

        pub fn getIndexOf(self: Self, context: anytype, item: T) OrderFnError(?usize) {
            const pos = if (returns_error) try self.getItemPosition(context, item) else self.getItemPosition(context, item);

            return if (pos.found_existing) pos.index else null;
        }

        pub fn ensureUnusedCapacity(self: *Self, alc: Allocator, len: usize) Allocator.Error!void {
            return self.ensureTotalCapacity(alc, std.math.add(usize, self.items.len, len) catch return error.OutOfMemory);
        }

        pub fn ensureTotalCapacity(self: *Self, alc: Allocator, len: usize) Allocator.Error!void {
            if (self.capacity >= len)
                return;

            const better_capacity = growCapacity(self.capacity, len);

            try self.resizeAllocatedSlice(alc, better_capacity);
        }

        fn resizeAllocatedSlice(self: *Self, alc: Allocator, new_len: usize) Allocator.Error!void {
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

        fn removeAt(self: *Self, i: usize) T {
            const discarded = self.items[i];

            std.mem.copyForwards(T, self.items[i..(self.items.len - 1)], self.items[(i + 1)..]);
            self.items.len -= 1;

            return discarded;
        }

        fn insertAt(self: *Self, i: usize, item: T) void {
            self.items.len += 1;
            std.mem.copyBackwards(T, self.items[(i + 1)..], self.items[i .. self.items.len - 1]);
            self.items[i] = item;
        }

        fn order(context: Context, a: T, b: T) !math.Order {
            return orderFn(context, a, b);
        }

        fn OrderFnError(comptime ReturnType: type) type {
            const ReturnErrorSet: ?type, const ReturnPayload: type = return_type: {
                const return_type_info = @typeInfo(ReturnType);

                if (return_type_info == .ErrorUnion) {
                    break :return_type struct { ?type, type }{ return_type_info.ErrorUnion.error_set, return_type_info.ErrorUnion.payload };
                } else {
                    break :return_type struct { ?type, type }{ null, ReturnType };
                }
            };

            return if (ReturnErrorSet) |ErrorSet|
                (if (OrderFnErrorSet()) |OrderErrorSet| (OrderErrorSet || ErrorSet)!ReturnPayload else ReturnType)
            else
                (if (OrderFnErrorSet()) |OrderErrorSet| OrderErrorSet!ReturnPayload else ReturnPayload);
        }

        fn OrderFnErrorSet() ?type {
            return if (returns_error) ret_info.ErrorUnion.error_set else null;
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

test "Testing ordered list" {
    const order = @import("order.zig");
    const alc = std.testing.allocator;

    var asc_list = try OrderedList(u32, order.asc(u32)).initCapacity(alc, 3);
    defer asc_list.deinit(alc);

    _ = asc_list.insertAssumeCapacity({}, 32);
    _ = asc_list.insertAssumeCapacity({}, 99);
    _ = asc_list.insertAssumeCapacity({}, 0);

    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 32, 99 }, asc_list.items);

    const desc_list = try asc_list.rearrange(alc, order.desc(u32), {});
    defer desc_list.deinit(alc);

    try std.testing.expectEqualSlices(u32, &[_]u32{ 99, 32, 0 }, desc_list.items);
}

test "Testing ordered string list" {
    const order = @import("order.zig");
    const alc = std.testing.allocator;

    var asc = try OrderedList([]const u8, order.ascString).initCapacity(alc, 9);
    defer asc.deinit(alc);

    _ = asc.insertAssumeCapacity({}, "johto");
    _ = asc.insertAssumeCapacity({}, "Hoenn");
    _ = asc.insertAssumeCapacity({}, "Sinnoh");
    _ = asc.insertAssumeCapacity({}, "alola");
    _ = asc.insertAssumeCapacity({}, "Kalos");
    _ = asc.insertAssumeCapacity({}, "unova");
    _ = asc.insertAssumeCapacity({}, "Kanto");
    _ = asc.insertAssumeCapacity({}, "galar");
    _ = asc.insertAssumeCapacity({}, "PALDEA");

    try std.testing.expectEqual(9, asc.items.len);
    try std.testing.expectEqualStrings("Hoenn", asc.items[0]);
    try std.testing.expectEqualStrings("Kalos", asc.items[1]);
    try std.testing.expectEqualStrings("Kanto", asc.items[2]);
    try std.testing.expectEqualStrings("PALDEA", asc.items[3]);
    try std.testing.expectEqualStrings("Sinnoh", asc.items[4]);
    try std.testing.expectEqualStrings("alola", asc.items[5]);
    try std.testing.expectEqualStrings("galar", asc.items[6]);
    try std.testing.expectEqualStrings("johto", asc.items[7]);
    try std.testing.expectEqualStrings("unova", asc.items[8]);

    var ascignorecase: OrderedList([]const u8, order.ascStringIgnoreCase) = try asc.rearrange(alc, order.ascStringIgnoreCase, {});
    defer ascignorecase.deinit(alc);

    try std.testing.expectEqual(9, ascignorecase.items.len);
    try std.testing.expectEqualStrings("alola", ascignorecase.items[0]);
    try std.testing.expectEqualStrings("galar", ascignorecase.items[1]);
    try std.testing.expectEqualStrings("Hoenn", ascignorecase.items[2]);
    try std.testing.expectEqualStrings("johto", ascignorecase.items[3]);
    try std.testing.expectEqualStrings("Kalos", ascignorecase.items[4]);
    try std.testing.expectEqualStrings("Kanto", ascignorecase.items[5]);
    try std.testing.expectEqualStrings("PALDEA", ascignorecase.items[6]);
    try std.testing.expectEqualStrings("Sinnoh", ascignorecase.items[7]);
    try std.testing.expectEqualStrings("unova", ascignorecase.items[8]);
}
