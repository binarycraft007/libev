const std = @import("std");
const os = std.os;
const builtin = @import("builtin");

pub const Loop = @import("ev/Loop.zig");
pub const Watcher = @import("ev/Watcher.zig");
pub const StreamServer = @import("ev/StreamServer.zig");

pub const Events = packed struct(c_int) {
    read: bool = false, // ev_io detected read will not block
    write: bool = false, // ev_io detected write will not block
    dummy0: bool = false,
    dummy1: bool = false,
    dummy2: bool = false,
    dummy3: bool = false,
    dummy4: bool = false,
    io_fdset: bool = false, // internal use only
    timer: bool = false, // timer timed out
    periodic: bool = false, // periodic timer timed out
    signal: bool = false, // signal was received
    child: bool = false, // child/pid had status change
    stat: bool = false, // stat data changed
    idle: bool = false, // event loop is idling
    prepare: bool = false, // event loop about to poll
    check: bool = false, // event loop finished poll
    embed: bool = false, // embedded event loop needs sweep
    fork: bool = false, // event loop resumed in child
    cleanup: bool = false, // event loop resumed in child
    @"async": bool = false, // async intra-loop signal
    dummy5: bool = false,
    dummy6: bool = false,
    dummy7: bool = false,
    dummy8: bool = false,
    custom: bool = false, // for use by user code
    dummy9: bool = false,
    dummy10: bool = false,
    dummy11: bool = false,
    dummy12: bool = false,
    dummy13: bool = false,
    dummy14: bool = false,
    @"error": bool = false, // sent when an error occurs
};

pub fn set_nonblocking(sock: os.socket_t) !void {
    switch (builtin.target.os.tag) {
        .windows => {
            var mode: u32 = 1;
            const cmd = os.windows.ws2_32.FIONBIO;
            if (os.windows.ws2_32.ioctlsocket(sock, cmd, &mode) != 0) {
                switch (os.windows.ws2_32.WSAGetLastError()) {
                    else => |err| return os.windows.unexpectedWSAError(err),
                }
            }
        },
        else => {
            var fd = try os.fcntl(sock, os.F.GETFD, 0);
            _ = try os.fcntl(@intCast(fd), os.F.SETFD, os.O.NONBLOCK);
        },
    }
}
