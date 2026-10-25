const std = @import("std");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

pub const CountingAllocator = struct {
    child: Allocator,
    live_bytes: usize = 0,
    peak_bytes: usize = 0,

    pub fn allocator(self: *CountingAllocator) Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn account(self: *CountingAllocator, old_len: usize, new_len: usize) void {
        self.live_bytes = self.live_bytes - old_len + new_len;
        self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const ptr = self.child.rawAlloc(len, alignment, ret_addr) orelse return null;
        self.account(0, len);
        return ptr;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        if (!self.child.rawResize(memory, alignment, new_len, ret_addr)) return false;
        self.account(memory.len, new_len);
        return true;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const ptr = self.child.rawRemap(memory, alignment, new_len, ret_addr) orelse return null;
        self.account(memory.len, new_len);
        return ptr;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ret_addr);
        self.account(memory.len, 0);
    }
};

test "counting allocator tracks allocations, resizing, remapping, and freeing" {
    var counting: CountingAllocator = .{ .child = std.testing.allocator };
    const allocator = counting.allocator();
    var bytes = try allocator.alloc(u8, 100);
    try std.testing.expectEqual(100, counting.live_bytes);
    if (allocator.resize(bytes, 50)) bytes = bytes[0..50];
    try std.testing.expectEqual(bytes.len, counting.live_bytes);
    if (allocator.remap(bytes, 200)) |moved| bytes = moved;
    try std.testing.expectEqual(bytes.len, counting.live_bytes);
    bytes = try allocator.realloc(bytes, 400);
    try std.testing.expectEqual(400, counting.live_bytes);
    try std.testing.expect(counting.peak_bytes >= 400);
    allocator.free(bytes);
    try std.testing.expectEqual(0, counting.live_bytes);
}

test "failed allocation does not change counts" {
    var counting: CountingAllocator = .{ .child = std.testing.failing_allocator };
    try std.testing.expectError(error.OutOfMemory, counting.allocator().alloc(u8, 1));
    try std.testing.expectEqual(0, counting.live_bytes);
    try std.testing.expectEqual(0, counting.peak_bytes);
}

test "successful and failed size changes preserve accounting" {
    var buffer: [512]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    var counting: CountingAllocator = .{ .child = fixed.allocator() };
    const allocator = counting.allocator();
    var bytes = try allocator.alloc(u8, 256);
    try std.testing.expect(allocator.resize(bytes, 128));
    bytes = bytes[0..128];
    try std.testing.expectEqual(128, counting.live_bytes);
    bytes = allocator.remap(bytes, 200) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(200, counting.live_bytes);
    try std.testing.expect(!allocator.resize(bytes, 1024));
    try std.testing.expect(allocator.remap(bytes, 1024) == null);
    try std.testing.expectEqual(200, counting.live_bytes);
    try std.testing.expectEqual(256, counting.peak_bytes);
    allocator.free(bytes);
    try std.testing.expectEqual(0, counting.live_bytes);
}
