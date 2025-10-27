# Quick Fix Guide - Critical Bugs Only

This document shows the exact changes needed to fix the 5 critical bugs.

---

## Fix 1: RedBlackTree - Change `self` Parameter Type

**File**: `src/ordered/red_black_tree.zig`

### Change 1: count() method (line ~121)
```zig
// BEFORE
pub fn count(self: Self) usize {
    return self.size;
}

// AFTER
pub fn count(self: *const Self) usize {
    return self.size;
}
```

### Change 2: get() method (line ~431)
```zig
// BEFORE
pub fn get(self: Self, data: T) ?*Node {
    var current = self.root;
    // ... rest of code

// AFTER
pub fn get(self: *const Self, data: T) ?*Node {
    var current = self.root;
    // ... rest of code
```

### Change 3: contains() method (line ~451)
```zig
// BEFORE
pub fn contains(self: Self, data: T) bool {
    return self.get(data) != null;
}

// AFTER
pub fn contains(self: *const Self, data: T) bool {
    return self.get(data) != null;
}
```

**Total changes**: 3 lines (just change `self: Self` to `self: *const Self`)

---

## Fix 2: CartesianTree - Remove `undefined` Parameter

**File**: `src/ordered/cartesian_tree.zig`

### Change: getNodePtr() method (line ~227-237)

**Option A - Remove unused parameter (RECOMMENDED):**
```zig
// BEFORE
fn getNodePtr(_: *Self, root: ?*Node, key: K) ?*V {
    if (root == null) return null;
    const node = root.?;
    const key_cmp = std.math.order(key, node.key);
    return switch (key_cmp) {
        .eq => &node.value,
        .lt => getNodePtr(undefined, node.left, key),
        .gt => getNodePtr(undefined, node.right, key),
    };
}

// AFTER
fn getNodePtr(root: ?*Node, key: K) ?*V {
    if (root == null) return null;
    const node = root.?;
    const key_cmp = std.math.order(key, node.key);
    return switch (key_cmp) {
        .eq => &node.value,
        .lt => getNodePtr(node.left, key),
        .gt => getNodePtr(node.right, key),
    };
}
```

**AND update the caller (line ~223):**
```zig
// BEFORE
pub fn getPtr(self: *Self, key: K) ?*V {
    return self.getNodePtr(self.root, key);
}

// AFTER
pub fn getPtr(self: *Self, key: K) ?*V {
    return Self.getNodePtr(self.root, key);
}
```

**Option B - Call correctly (alternative):**
```zig
// Keep signature, fix calls
fn getNodePtr(_: *Self, root: ?*Node, key: K) ?*V {
    if (root == null) return null;
    const node = root.?;
    const key_cmp = std.math.order(key, node.key);
    return switch (key_cmp) {
        .eq => &node.value,
        .lt => Self.getNodePtr(undefined, node.left, key),  // Still weird but valid
        .gt => Self.getNodePtr(undefined, node.right, key),
    };
}
```

**Recommendation**: Use Option A (cleaner)

---

## Fix 3: BTreeMap - Propagate splitChild Error

**File**: `src/ordered/btree_map.zig`

### Change 1: splitChild signature (line ~223)
```zig
// BEFORE
fn splitChild(self: *Self, parent: *Node, index: u16) void {
    const child = parent.children[index].?;
    const new_sibling = self.createNode() catch @panic("OOM");
    // ... rest

// AFTER
fn splitChild(self: *Self, parent: *Node, index: u16) !void {
    const child = parent.children[index].?;
    const new_sibling = try self.createNode();
    // ... rest
```

### Change 2: Update all callers to use `try`

**Caller 1** (line ~213 in put method):
```zig
// BEFORE
self.splitChild(new_root, 0);

// AFTER
try self.splitChild(new_root, 0);
```

**Caller 2** (line ~303 in insertNonFull method):
```zig
// BEFORE
self.splitChild(node, i);

// AFTER
try self.splitChild(node, i);
```

**Total changes**: 3 lines (1 signature + 2 call sites)

---

## Fix 4: Trie Iterator - Propagate Allocation Errors

**File**: `src/ordered/trie.zig`

### Change: Iterator.next() method (line ~358)

```zig
// BEFORE
pub fn next(self: *Iterator) ?struct { key: []const u8, value: V } {
    while (self.stack.items.len > 0) {
        var frame = &self.stack.items[self.stack.items.len - 1];

        if (!frame.visited_self and frame.node.is_end) {
            frame.visited_self = true;
            return .{ .key = self.current_key.items, .value = frame.node.value.? };
        }

        if (frame.child_iter.next()) |entry| {
            const char = entry.key_ptr.*;
            const child = entry.value_ptr.*;

            self.current_key.append(self.allocator, char) catch return null;  // ❌

            self.stack.append(self.allocator, IteratorFrame{
                .node = child,
                .child_iter = child.children.iterator(),
                .visited_self = false,
            }) catch return null;  // ❌
        } else {
            _ = self.stack.pop();
            if (self.current_key.items.len > 0) {
                _ = self.current_key.pop();
            }
        }
    }
    return null;
}

// AFTER
pub fn next(self: *Iterator) !?struct { key: []const u8, value: V } {
    while (self.stack.items.len > 0) {
        var frame = &self.stack.items[self.stack.items.len - 1];

        if (!frame.visited_self and frame.node.is_end) {
            frame.visited_self = true;
            return .{ .key = self.current_key.items, .value = frame.node.value.? };
        }

        if (frame.child_iter.next()) |entry| {
            const char = entry.key_ptr.*;
            const child = entry.value_ptr.*;

            try self.current_key.append(self.allocator, char);  // ✅

            try self.stack.append(self.allocator, IteratorFrame{  // ✅
                .node = child,
                .child_iter = child.children.iterator(),
                .visited_self = false,
            });
        } else {
            _ = self.stack.pop();
            if (self.current_key.items.len > 0) {
                _ = self.current_key.pop();
            }
        }
    }
    return null;
}
```

**Total changes**: 3 lines (1 return type + 2 error handling)

**NOTE**: All code that uses this iterator will need to be updated to handle the error:
```zig
// BEFORE
while (iter.next()) |entry| { ... }

// AFTER  
while (try iter.next()) |entry| { ... }
```

---

## Fix 5: BTreeMap - Add Iterator (More Complex)

**File**: `src/ordered/btree_map.zig`

This is the most complex fix. Here's a minimal iterator implementation:

```zig
pub const Iterator = struct {
    stack: std.ArrayList(StackFrame),
    allocator: std.mem.Allocator,

    const StackFrame = struct {
        node: *Node,
        index: u16,
    };

    fn init(allocator: std.mem.Allocator, root: ?*Node) !Iterator {
        var stack = std.ArrayList(StackFrame){};
        
        if (root) |r| {
            try stack.append(allocator, StackFrame{ .node = r, .index = 0 });
            // Descend to leftmost node
            var current = r;
            while (!current.is_leaf) {
                if (current.children[0]) |child| {
                    try stack.append(allocator, StackFrame{ .node = child, .index = 0 });
                    current = child;
                } else break;
            }
        }

        return Iterator{
            .stack = stack,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Iterator) void {
        self.stack.deinit(self.allocator);
    }

    pub fn next(self: *Iterator) !?struct { key: K, value: V } {
        while (self.stack.items.len > 0) {
            var frame = &self.stack.items[self.stack.items.len - 1];
            
            if (frame.index < frame.node.len) {
                const result = .{
                    .key = frame.node.keys[frame.index],
                    .value = frame.node.values[frame.index],
                };
                
                // Move to next position
                if (!frame.node.is_leaf) {
                    // Go to right child of current key
                    if (frame.node.children[frame.index + 1]) |child| {
                        frame.index += 1;
                        try self.stack.append(self.allocator, StackFrame{ .node = child, .index = 0 });
                        
                        // Descend to leftmost
                        var current = child;
                        while (!current.is_leaf) {
                            if (current.children[0]) |left_child| {
                                try self.stack.append(self.allocator, StackFrame{ .node = left_child, .index = 0 });
                                current = left_child;
                            } else break;
                        }
                    } else {
                        frame.index += 1;
                    }
                } else {
                    frame.index += 1;
                }
                
                return result;
            } else {
                _ = self.stack.pop();
            }
        }
        
        return null;
    }
};

pub fn iterator(self: *const Self) !Iterator {
    return Iterator.init(self.allocator, self.root);
}
```

**NOTE**: This is a basic in-order iterator. You may want to test it thoroughly and optimize.

---

## Testing Your Fixes

After making these changes, run:

```bash
zig build test
```

All tests should still pass. If they don't, the issue is likely in:
1. RedBlackTree tests calling methods (they may need `&tree` instead of `tree`)
2. Trie iterator usage in tests (need to add `try`)
3. CartesianTree tests if any use getPtr

---

## Summary

| Fix | File | Lines Changed | Complexity |
|-----|------|---------------|------------|
| 1. RedBlackTree params | red_black_tree.zig | 3 | ⭐ Easy |
| 2. CartesianTree undefined | cartesian_tree.zig | 4 | ⭐ Easy |
| 3. BTreeMap panic | btree_map.zig | 3 | ⭐⭐ Medium |
| 4. Trie iterator | trie.zig | 3 + test updates | ⭐⭐ Medium |
| 5. BTreeMap iterator | btree_map.zig | ~60 | ⭐⭐⭐ Hard |

**Total estimated time**: 2-4 hours

