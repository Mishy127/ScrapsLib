const io = @import("std").io;

const DataReader = @This();
data: []const u8,
index: usize = 0,

pub fn init(data: []const u8) DataReader {
    return .{ .data = data, .index = 0 };
}

pub const Error = error{};

pub fn read(self: *DataReader, dest: []u8) error{}!usize {
    const chunk = self.data[self.index..][0..@min(dest.len, self.data.len - self.index)];

    @memcpy(dest[0..chunk.len], chunk);

    self.index += chunk.len;

    return chunk.len;
}

pub fn reader(self: *DataReader) io.GenericReader(*DataReader, Error, read) {
    return .{ .context = self };
}
