const std = @import("std");
const os = std.os;
const mem = std.mem;
const net = std.net;
const StreamServer = @This();
/// Copied from `Options` on `init`.
kernel_backlog: u31,
reuse_address: bool,
reuse_port: bool,

/// `undefined` until `listen` returns successfully.
listen_address: net.Address,

sockfd: ?os.socket_t,

pub const Options = struct {
    /// How many connections the kernel will accept on the application's behalf.
    /// If more than this many connections pool in the kernel, clients will start
    /// seeing "Connection refused".
    kernel_backlog: u31 = 128,

    /// Enable SO.REUSEADDR on the socket.
    reuse_address: bool = false,

    /// Enable SO.REUSEPORT on the socket.
    reuse_port: bool = false,
};

/// After this call succeeds, resources have been acquired and must
/// be released with `deinit`.
pub fn init(options: Options) StreamServer {
    return StreamServer{
        .sockfd = null,
        .kernel_backlog = options.kernel_backlog,
        .reuse_address = options.reuse_address,
        .reuse_port = options.reuse_port,
        .listen_address = undefined,
    };
}

/// Release all resources. The `StreamServer` memory becomes `undefined`.
pub fn deinit(self: *StreamServer) void {
    self.close();
    self.* = undefined;
}

pub fn listen(self: *StreamServer, address: net.Address) !void {
    const sock_flags = os.SOCK.STREAM | os.SOCK.CLOEXEC | os.SOCK.NONBLOCK;
    const proto = if (address.any.family == os.AF.UNIX) @as(u32, 0) else os.IPPROTO.TCP;

    const sockfd = try os.socket(address.any.family, sock_flags, proto);
    self.sockfd = sockfd;
    errdefer {
        os.closeSocket(sockfd);
        self.sockfd = null;
    }

    if (self.reuse_address) {
        try os.setsockopt(
            sockfd,
            os.SOL.SOCKET,
            os.SO.REUSEADDR,
            &mem.toBytes(@as(c_int, 1)),
        );
    }
    if (@hasDecl(os.SO, "REUSEPORT") and self.reuse_port) {
        try os.setsockopt(
            sockfd,
            os.SOL.SOCKET,
            os.SO.REUSEPORT,
            &mem.toBytes(@as(c_int, 1)),
        );
    }

    var socklen = address.getOsSockLen();
    try os.bind(sockfd, &address.any, socklen);
    try os.listen(sockfd, self.kernel_backlog);
    try os.getsockname(sockfd, &self.listen_address.any, &socklen);
}

/// Stop listening. It is still necessary to call `deinit` after stopping listening.
/// Calling `deinit` will automatically call `close`. It is safe to call `close` when
/// not listening.
pub fn close(self: *StreamServer) void {
    if (self.sockfd) |fd| {
        os.closeSocket(fd);
        self.sockfd = null;
        self.listen_address = undefined;
    }
}

pub const AcceptError = error{
    ConnectionAborted,

    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    /// Not enough free memory.  This often means that the memory allocation  is  limited
    /// by the socket buffer limits, not by the system memory.
    SystemResources,

    /// Socket is not listening for new connections.
    SocketNotListening,

    ProtocolFailure,

    /// Firewall rules forbid connection.
    BlockedByFirewall,

    FileDescriptorNotASocket,

    ConnectionResetByPeer,

    NetworkSubsystemFailed,

    OperationNotSupported,
} || os.UnexpectedError;

pub const Connection = struct {
    stream: net.Stream,
    address: net.Address,
};

/// If this function succeeds, the returned `Connection` is a caller-managed resource.
pub fn accept(self: *StreamServer) AcceptError!Connection {
    var accepted_addr: net.Address = undefined;
    var adr_len: os.socklen_t = @sizeOf(net.Address);
    const accept_result = os.accept(
        self.sockfd.?,
        &accepted_addr.any,
        &adr_len,
        os.SOCK.CLOEXEC,
    );

    if (accept_result) |fd| {
        return Connection{
            .stream = net.Stream{ .handle = fd },
            .address = accepted_addr,
        };
    } else |err| switch (err) {
        error.WouldBlock => unreachable,
        else => |e| return e,
    }
}
