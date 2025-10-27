const std = @import("std");
const ordered = @import("ordered");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## TrieMap Example ##\n", .{});
    var trie = try ordered.TrieMap([]const u8).init(allocator);
    defer trie.deinit();

    try trie.put("cat", "feline");
    try trie.put("car", "vehicle");
    try trie.put("card", "playing card");
    try trie.put("care", "to look after");
    try trie.put("careful", "cautious");

    std.debug.print("TrieMap count: {d}\n", .{trie.count()});

    if (trie.get("car")) |value_ptr| {
        std.debug.print("Found 'car': {s}\n", .{value_ptr.*});
    }

    std.debug.print("Has prefix 'car'? {any}\n", .{trie.hasPrefix("car")});
    std.debug.print("Contains 'ca'? {any}\n", .{trie.contains("ca")});

    std.debug.print("Keys with prefix 'car': ", .{});
    var prefix_iter = try trie.keysWithPrefix(allocator, "car");
    defer prefix_iter.deinit();

    var first = true;
    while (try prefix_iter.next()) |key| {
        if (!first) std.debug.print(", ", .{});
        std.debug.print("'{s}'", .{key});
        first = false;
    }
    std.debug.print("\n", .{});

    const removed = trie.remove("card");
    std.debug.print("Removed 'card' with value: {?s}\n", .{removed});
    std.debug.print("Contains 'card' after remove? {any}\n\n", .{trie.contains("card")});
}
