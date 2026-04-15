//! A minimal replacement for `std.time.Timer`, which was removed from the
//! standard library in Zig 0.16. Backed by `std.Io.Timestamp` on the
//! monotonic `.real` clock. API-compatible with the subset of the old
//! Timer that the ordered benchmarks use (`start`, `read`, `lap`).
const std = @import("std");

pub const Timer = struct {
    start_ns: i96,

    pub fn start() !Timer {
        return .{ .start_ns = Timer.now() };
    }

    /// Nanoseconds since the last `start`/`lap`. Does not modify state.
    pub fn read(self: *const Timer) u64 {
        return @intCast(Timer.now() - self.start_ns);
    }

    /// Returns nanoseconds since the last `start`/`lap` and resets the
    /// internal start to the current instant.
    pub fn lap(self: *Timer) u64 {
        const now_ns = Timer.now();
        const elapsed = now_ns - self.start_ns;
        self.start_ns = now_ns;
        return @intCast(elapsed);
    }

    fn now() i96 {
        return std.Io.Timestamp.now(std.Options.debug_io, .real).nanoseconds;
    }
};
