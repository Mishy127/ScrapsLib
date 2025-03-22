const std = @import("std");

pub fn CriticalPoint(comptime T: type) type {
    return struct {
        const Self = @This();
        value: T,
        mutex: std.Thread.Mutex,

        pub fn init(value: T) Self {
            return .{
                .value = value,
                .mutex = .{},
            };
        }

        pub fn get(self: *Self) *T {
            self.mutex.lock();

            return @ptrCast(&self.value);
        }

        pub fn tryGet(self: *Self) ?*T {
            return if (self.mutex.tryLock()) @ptrCast(&self.value) else null;
        }

        pub fn release(self: *Self) void {
            self.mutex.unlock();
        }
    };
}
