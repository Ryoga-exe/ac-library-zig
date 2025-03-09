const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn SimpleQueue(comptime T: type) type {
    const ArrayList = std.ArrayList(T);

    return struct {
        const Self = @This();

        allocator: Allocator,
        payload: ArrayList,
        pos: usize,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .payload = .init(allocator),
                .pos = 0,
            };
        }

        pub fn initCapacity(allocator: Allocator, n: usize) Allocator.Error!Self {
            return Self{
                .allocator = allocator,
                .payload = try .initCapacity(allocator, n),
                .pos = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.payload.deinit();
        }

        pub fn size(self: Self) usize {
            return self.payload.items.len - self.pos;
        }

        pub fn empty(self: Self) bool {
            return self.pos == self.payload.items.len;
        }

        pub fn push(self: *Self, t: T) Allocator.Error!void {
            return self.payload.append(t);
        }

        pub fn pushAssumeCapacity(self: *Self, t: T) void {
            self.payload.appendAssumeCapacity(t);
        }

        pub fn front(self: Self) ?T {
            return if (self.pos < self.payload.items.len)
                self.payload.items[self.pos]
            else
                null;
        }

        pub fn clearAndFree(self: *Self) void {
            self.payload.clearAndFree();
            self.pos = 0;
        }

        pub fn pop(self: *Self) ?T {
            if (self.pos < self.payload.items.len) {
                defer self.pos += 1;
                return self.payload.items[self.pos];
            } else {
                return null;
            }
        }
    };
}

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
test SimpleQueue {
    const allocator = testing.allocator;
    var queue = SimpleQueue(usize).init(allocator);
    defer queue.deinit();

    try expectEqual(0, queue.size());
    try expect(queue.empty());
    try expectEqual(null, queue.front());
    try expectEqual(null, queue.pop());

    try queue.push(123);

    try expectEqual(1, queue.size());
    try expect(!queue.empty());
    try expectEqual(123, queue.front());

    try queue.push(456);

    try expectEqual(2, queue.size());
    try expect(!queue.empty());
    try expectEqual(123, queue.front());

    try expectEqual(123, queue.pop());
    try expectEqual(1, queue.size());
    try expect(!queue.empty());
    try expectEqual(456, queue.front());

    try queue.push(789);
    try queue.push(789);
    try queue.push(456);
    try queue.push(456);

    try expectEqual(5, queue.size());
    try expect(!queue.empty());
    try expectEqual(456, queue.front());

    try expectEqual(456, queue.pop());
    try expectEqual(4, queue.size());
    try expect(!queue.empty());
    try expectEqual(789, queue.front());

    queue.clearAndFree();

    try expectEqual(0, queue.size());
    try expect(queue.empty());
    try expectEqual(null, queue.front());
    try expectEqual(null, queue.pop());
}
