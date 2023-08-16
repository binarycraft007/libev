const std = @import("std");
const c = @import("../c.zig");
const Loop = @This();

inner: *c.struct_ev_loop,

pub fn init() Loop {
    return .{ .inner = c.ev_default_loop(0).? };
}

pub const RunMode = enum(u2) {
    until_done = 0, // until loop exit
    no_wait = 1, // do not block/wait
    once = 2, // block once only
};

pub fn run(self: *Loop, mode: RunMode) void {
    _ = c.ev_run(self.inner, @intFromEnum(mode));
}
