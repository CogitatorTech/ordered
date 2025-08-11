const std = @import("std");
const ordered = @import("ordered");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## Trie Example ##\n", .{});
    var trie = try ordered.Trie([]const u8).init(allocator);
    defer trie.deinit();

    try trie.put("cat", "feline");
    try trie.put("car", "vehicle");
    try trie.put("card", "playing card");
    try trie.put("care", "to look after");
    try trie.put("careful", "cautious");

    std.debug.print("Trie length: {d}\n", .{trie.len});

    if (trie.get("car")) |value_ptr| {
        std.debug.print("Found 'car': {s}\n", .{value_ptr.*});
    }

    std.debug.print("Has prefix 'car'? {any}\n", .{trie.hasPrefix("car")});
    std.debug.print("Contains 'ca'? {any}\n", .{trie.contains("ca")});

    var keys = try trie.keysWithPrefix(allocator, "car");
    defer {
        for (keys.items) |key| {
            allocator.free(key);
        }
        keys.deinit(allocator);
    }

    std.debug.print("Keys with prefix 'car': ", .{});
    for (keys.items, 0..) |key, i| {
        if (i > 0) std.debug.print(", ", .{});
        std.debug.print("'{s}'", .{key});
    }
    std.debug.print("\n", .{});

    _ = trie.delete("card");
    std.debug.print("Contains 'card' after delete? {any}\n", .{trie.contains("card")});
}
