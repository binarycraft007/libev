const std = @import("std");
const c = @import("../c.zig");
const builtin = @import("builtin");
const Loop = @import("Loop.zig");
const ev = @import("../ev.zig");
const Watcher = @This();

inner: c.struct_ev_io,
loop: *Loop,
callback: CallBackFn,
user_data: ?*anyopaque,

fn cb(_: ?*c.struct_ev_loop, w: [*c]c.ev_io, evs: c_int) callconv(.C) void {
    var events: ev.Events = @bitCast(evs);
    if (events.@"error") {
        std.log.err("callback event", .{});
        return;
    }

    var watcher: *Watcher = @alignCast(@ptrCast(w[0].data.?));
    watcher.callback(@ptrCast(watcher)) catch |err| {
        std.log.err("callback: {}", .{err});
        return;
    };
}

// should be *Watcher instead of *anyopaque, workaround for
// compiler bug, dependency loop detected.
pub const CallBackFn = *const fn (_: *anyopaque) anyerror!void;

pub const InitOptions = struct {
    fd: std.os.fd_t,
    callback: CallBackFn,
    loop: *Loop,
    events: ev.Events,
    user_data: ?*anyopaque = null,
};

pub fn init(options: InitOptions) Watcher {
    return .{
        .inner = .{
            .active = 0,
            .pending = 0,
            .priority = 0,
            .data = null,
            .cb = cb,
            .next = undefined,
            .fd = switch (builtin.target.os.tag) {
                .windows => @intCast(@intFromPtr(options.fd)),
                else => options.fd,
            },
            .events = blk: {
                var events_tmp = options.events;
                events_tmp.io_fdset = true;
                break :blk @bitCast(events_tmp);
            },
        },
        .user_data = options.user_data,
        .callback = options.callback,
        .loop = options.loop,
    };
}

pub fn start(self: *Watcher) void {
    self.inner.data = @ptrCast(self);
    c.ev_io_start(self.loop.inner, &self.inner);
}

pub fn stop(self: *Watcher) void {
    c.ev_io_stop(self.loop.inner, &self.inner);
}
