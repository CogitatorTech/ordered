const std = @import("std");
const comparison = @import("util/comparison.zig");

pub fn main(init: std.process.Init) !void {
    try comparison.run(init, true);
}
