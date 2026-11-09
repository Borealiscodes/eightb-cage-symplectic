const std = @import("std");

pub const RationalState2N = @import("main.zig").RationalState2N;

test "base layout validation" {
    try std.testing.expectEqual(@sizeOf(RationalState2N), @sizeOf(usize) * 4);
}
