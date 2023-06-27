const network = @import("network");
const page_allocator = @import("std").heap.page_allocator;
const print = @import("std").debug.print;

pub const Server = struct {
    port: u16,

    pub fn start(self: *Server) !void {
        try network.init();
        defer network.deinit();

        var socket = try network.Socket.create(.ipv4, .tcp);
        defer socket.close();
        try socket.bindToPort(self.port);

        try socket.listen();
        while (true) {
            var client = try socket.accept();
            defer client.close();
            print("Client connected from {}\n", .{try client.getLocalEndPoint()});
        }
    }
};

test "Start the server" {
    var server = Server{
        .port = 8000,
    };

    try server.start();
}
