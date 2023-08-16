const std = @import("std");
const net = std.net;
const ev = @import("ev");
const testing = std.testing;

test "stream server" {
    var loop = ev.Loop.init();

    const localhost = try net.Address.parseIp("127.0.0.1", 0);
    var server = ev.StreamServer.init(.{});
    defer server.deinit();

    try server.listen(localhost);

    var watcher = ev.Watcher.init(.{
        .fd = server.sockfd.?,
        .callback = &callback,
        .loop = &loop,
        .events = .{ .read = true },
        .user_data = @ptrCast(&server),
    });
    watcher.start(); // start the watcher

    const socket = try net.tcpConnectToAddress(server.listen_address);
    defer socket.close();

    try ev.set_nonblocking(socket.handle);
    _ = try socket.writer().writeAll("Hello world!");

    loop.run(.until_done); // run the loop
}

fn callback(w: *anyopaque) anyerror!void {
    var watcher: *ev.Watcher = @alignCast(@ptrCast(w));
    defer watcher.stop();

    var server: *ev.StreamServer = @alignCast(@ptrCast(watcher.user_data));
    var client = try server.accept();
    defer client.stream.close();

    try ev.set_nonblocking(client.stream.handle);

    var buf: [16]u8 = undefined;
    const n = try client.stream.reader().read(&buf);

    try testing.expectEqual(@as(usize, 12), n);
    try testing.expectEqualSlices(u8, "Hello world!", buf[0..n]);
}
