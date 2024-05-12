const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn GapBuffer(comptime T: type) type {
    const ItemTag = enum {
        item,
        gap,
    };
    const Item = union(ItemTag) { item: T, gap: void };
    return struct {
        const Self = @This();
        buffer: []Item,
        original_size: usize,
        gap_start: usize,
        gap_end: usize,
        gap_size: usize,
        allocator: *Allocator,
        pub fn init(allocator: *Allocator, size: usize) Allocator.Error!Self {
            const buffer = try allocator.alloc(T, size);
            if (buffer == null) {
                return null;
            }
            return GapBuffer(T){
                .buffer = buffer,
                .original_size = size,
                .gap_start = 0,
                .gap_end = size,
                .gap_size = size,
                .allocator = allocator,
            };
        }
        pub fn deinit(this: Self) void {
            this.allocator.dealloc(this.buffer);
        }
        pub fn grow_gap(this: *Self) Allocator.Error!void {
            var new_size = this.buffer.length + this.original_size;
            var new_buffer = try this.allocator.alloc(T, new_size);
            if (new_buffer == null) {
                return Allocator.Error.OutOfMemory;
            }
            var offset = 0;
            var set_new_gap_start = false;
            var set_new_gap_end = false;
            for (new_buffer, 0..) |_, i| {
                if (i >= this.buffer.length and offset == 0) {
                    new_buffer[i] = Item{ .gap = void };
                } else if (i >= this.buffer.length) {
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
        }
        pub fn insert(this: *Self, values: []const T, position: usize) Allocator.Error!void {
            if (position < this.buffer.length or position >= this.buffer.length) {
                return Allocator.Error.OutOfBounds;
            } else if (position + values.length >= this.buffer.length) {
                return Allocator.Error.OutOfBounds;
            }
            if (this.gap_size < values.length) {
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
            }
            if (this.gap_end == 0) {
                try this.grow_gap();
            }
        }
    };
}
