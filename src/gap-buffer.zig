const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = error{OutOfBounds} || Allocator.Error;

pub fn GapBuffer(comptime T: type) type {
    const ItemTag = enum {
        item,
        gap,
    };
    const Item = union(ItemTag) { item: T, gap: void };
    return struct {
        const Self = @This();
        buffer: []Item,
        length: usize,
        original_size: usize,
        gap_start: usize,
        gap_end: usize,
        gap_size: usize,
        allocator: *const Allocator,
        pub fn init(allocator: *const Allocator, size: usize) Error!Self {
            const buffer = try allocator.alloc(Item, size);
            return GapBuffer(T){
                .buffer = buffer,
                .length = size,
                .original_size = size,
                .gap_start = 0,
                .gap_end = size,
                .gap_size = size,
                .allocator = allocator,
            };
        }
        pub fn deinit(this: Self) void {
            this.allocator.free(this.buffer);
        }
        pub fn grow_gap(this: *Self) Error!void {
            var new_size = this.length + this.original_size;
            var new_buffer = try this.allocator.alloc(Item, new_size);
            var offset: usize = 0;
            var set_new_gap_start = false;
            var set_new_gap_end = false;
            for (new_buffer, 0..) |_, i| {
                if (i >= this.length and offset == 0) {
                    new_buffer[i] = Item.gap;
                } else if (i >= this.length) {
                    new_buffer[i] = this.buffer[i - offset];
                    if (!set_new_gap_end) {
                        this.gap_end = i;
                        set_new_gap_end = true;
                    }
                } else {
                    switch (this.buffer[i]) {
                        .item => {
                            new_buffer[i] = this.buffer[i];
                        },
                        .gap => {
                            offset = i;
                            if (!set_new_gap_start) {
                                this.gap_start = i;
                                set_new_gap_start = true;
                            }
                        },
                    }
                }
            }
            this.allocator.free(this.buffer);
            this.buffer = new_buffer;
            this.length = new_size;
        }
        pub fn insert(this: *Self, values: []const T, length: usize, position: usize) Error!void {
            if (position >= this.length) {
                return Error.OutOfBounds;
            } else if (position + length >= this.length) {
                return Error.OutOfBounds;
            }
            if (this.gap_size < length) {
                try this.grow_gap();
            }
            var index = position;
            for (values) |value| {
                if (index >= this.gap_start and index < this.gap_end) {
                    this.gap_start += 1;
                    this.gap_size -= 1;
                    if (this.gap_size == 0) {
                        this.gap_end = 0;
                    }
                }
                this.buffer[index] = Item{ .item = value };
                this.gap_start += 1;
                index += 1;
                if (this.gap_end == 0) {
                    try this.grow_gap();
                }
            }
        }
        pub fn move_gap_left(this: *Self, position: usize) void {
            while (this.gap_start > position) {
                this.gap_start -= 1;
                this.gap_end -= 1;
                this.buffer[this.gap_end] = this.buffer[this.gap_start];
                this.buffer[this.gap_start] = Item.gap;
            }
        }
        pub fn move_gap_right(this: *Self, position: usize) void {
            while (this.gap_end < position) {
                this.buffer[this.gap_start] = this.buffer[this.gap_end];
                this.gap_start += 1;
                this.gap_end += 1;
            }
        }
    };
}

test "test init" {
    var buffer = try GapBuffer(i32).init(&std.testing.allocator, 10);
    defer buffer.deinit();
    try buffer.insert(&[_]i32{ 1, 2, 3 }, 3, 0);
    try std.testing.expectEqual(@as(i32, 1), buffer.buffer[0].item);
    try std.testing.expectEqual(@as(i32, 2), buffer.buffer[1].item);
}

test "test insert" {
    var buffer = try GapBuffer(i32).init(&std.testing.allocator, 10);
    defer buffer.deinit();
    try buffer.insert(&[_]i32{ 1, 2, 3 }, 3, 0);
    try buffer.insert(&[_]i32{ 4, 5, 6 }, 3, 3);
    try std.testing.expectEqual(@as(i32, 1), buffer.buffer[0].item);
    try std.testing.expectEqual(@as(i32, 2), buffer.buffer[1].item);
    try std.testing.expectEqual(@as(i32, 3), buffer.buffer[2].item);
    try std.testing.expectEqual(@as(i32, 4), buffer.buffer[3].item);
    try std.testing.expectEqual(@as(i32, 5), buffer.buffer[4].item);
    try std.testing.expectEqual(@as(i32, 6), buffer.buffer[5].item);
}

test "test insert resize" {
    var buffer = try GapBuffer(i32).init(&std.testing.allocator, 3);
    defer buffer.deinit();
    try buffer.insert(&[_]i32{ 1, 2, 3 }, 3, 0);
    try buffer.insert(&[_]i32{ 4, 5, 6 }, 3, 3);
    try std.testing.expectEqual(@as(i32, 1), buffer.buffer[0].item);
    try std.testing.expectEqual(@as(i32, 2), buffer.buffer[1].item);
    try std.testing.expectEqual(@as(i32, 3), buffer.buffer[2].item);
    try std.testing.expectEqual(@as(i32, 4), buffer.buffer[3].item);
    try std.testing.expectEqual(@as(i32, 5), buffer.buffer[4].item);
    try std.testing.expectEqual(@as(i32, 6), buffer.buffer[5].item);
}
