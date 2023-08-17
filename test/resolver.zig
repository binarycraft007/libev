const std = @import("std");
const net = std.net;
const ev = @import("ev");
const testing = std.testing;

test "resolver" {
    var loop = ev.Loop.init();
    var resolver = try ev.Resolver.init(.{
        .loop = &loop,
        .name = "www.google.com",
        .name_server = "8.8.8.8",
        .allocator = testing.allocator,
        .callback = &getAddressListCallback,
    });
    try resolver.getAddressList();
    loop.run(.until_done); // run the loop
}

fn getAddressListCallback(
    addrs: ev.Resolver.AddressList,
) void {
    defer addrs.deinit(); // we own the memory
}
