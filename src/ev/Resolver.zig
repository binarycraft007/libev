const std = @import("std");
const dns = @import("dns");
const Loop = @import("Loop.zig");
const Watcher = @import("Watcher.zig");
const Resolver = @This();

pub const AddressList = struct {
    allocator: std.mem.Allocator,
    addrs: []std.net.Address,
    pub fn deinit(self: @This()) void {
        self.allocator.free(self.addrs);
    }
};

loop: *Loop,
send_ctx: Watcher,
recv_ctx: Watcher,
allocator: std.mem.Allocator,
name: []const u8,
name_server: []const u8,
conn: dns.helpers.DNSConnection,
callback: *const fn (AddressList) void,

const logger = std.log.scoped(.resolver);

const InitOptions = struct {
    loop: *Loop,
    name: []const u8,
    name_server: []const u8,
    allocator: std.mem.Allocator,
    callback: *const fn (AddressList) void,
};

pub fn init(options: InitOptions) !Resolver {
    return .{
        .conn = undefined,
        .loop = options.loop,
        .send_ctx = undefined,
        .recv_ctx = undefined,
        .allocator = options.allocator,
        .name_server = options.name_server,
        .callback = options.callback,
        .name = options.name,
    };
}

pub fn getAddressList(self: *Resolver) !void {
    var addr = try std.net.Address.parseIp(self.name_server, 53);

    var flags: u32 = std.os.SOCK.DGRAM | std.os.SOCK.NONBLOCK;
    const fd = try std.os.socket(addr.any.family, flags, std.os.IPPROTO.UDP);

    self.conn = .{
        .address = addr,
        .socket = std.net.Stream{ .handle = fd },
    };

    self.send_ctx = Watcher.init(.{
        .fd = self.conn.socket.handle,
        .callback = &sendCallback,
        .loop = self.loop,
        .events = .{ .write = true },
        .user_data = @ptrCast(self),
    });

    self.recv_ctx = Watcher.init(.{
        .fd = self.conn.socket.handle,
        .callback = &recvCallback,
        .loop = self.loop,
        .events = .{ .read = true },
        .user_data = @ptrCast(self),
    });

    self.send_ctx.start();
}

fn sendCallback(w: *anyopaque) !void {
    var watcher: *Watcher = @alignCast(@ptrCast(w));
    var self: *Resolver = @alignCast(@ptrCast(watcher.user_data));

    self.send_ctx.stop();

    defer self.recv_ctx.start();

    var name_buffer: [128][]const u8 = undefined;
    var name = try dns.Name.fromString(self.name, &name_buffer);

    var questions = [_]dns.Question{
        .{
            .name = name,
            .typ = .A,
            .class = .IN,
        },
        .{
            .name = name,
            .typ = .AAAA,
            .class = .IN,
        },
    };

    var packet = dns.Packet{
        .header = .{
            .id = dns.helpers.randomHeaderId(),
            .is_response = false,
            .wanted_recursion = true,
            .question_length = questions.len,
        },
        .questions = &questions,
        .answers = &[_]dns.Resource{},
        .nameservers = &[_]dns.Resource{},
        .additionals = &[_]dns.Resource{},
    };

    try self.conn.sendPacket(packet);
}

fn recvCallback(w: *anyopaque) !void {
    var watcher: *Watcher = @alignCast(@ptrCast(w));
    var self: *Resolver = @alignCast(@ptrCast(watcher.user_data));

    self.recv_ctx.stop();
    defer self.conn.close();

    var final_list = std.ArrayList(std.net.Address).init(self.allocator);
    defer final_list.deinit();

    var addrs = try dns.helpers.receiveTrustedAddresses(
        self.allocator,
        &self.conn,
        .{},
    );
    defer self.allocator.free(addrs);

    for (addrs) |addr| try final_list.append(addr);

    self.callback(.{
        .allocator = self.allocator,
        .addrs = try final_list.toOwnedSlice(),
    });
}
