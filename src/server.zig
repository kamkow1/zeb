const network = @import("network");
const page_allocator = @import("std").heap.page_allocator;
const print = @import("std").debug.print;

pub const Route = struct {
    path: []const u8,
    handler: *const fn () void,
};

pub fn Server(comptime port: u16) type {
    return struct {
        socket: ?network.Socket,
        routes: []Route,

        const Self = @This();

        fn closeServer(self: *Self) void {
            self.socket.?.close();
            network.deinit();
        }

        pub fn start(self: *Self) !void {
            try network.init();
            defer network.deinit();

            self.socket = try network.Socket.create(.ipv4, .tcp);
            defer self.socket.?.close();
            try self.socket.?.bindToPort(port);

            try self.socket.?.listen();
            while (true) {
                var client = try self.socket.?.accept();
                defer client.close();
                const endpoint = try client.getLocalEndPoint();
                print("Client connected from {d}\n", .{endpoint});

                var buffer: [1024]u8 = undefined;
                const len = try client.receive(&buffer);
                _ = len;
                print("Client said {s}", .{buffer});
            }
        }

        pub fn init(routes: []Route) Self {
            return Self{
                .socket = null,
                .routes = routes,
            };
        }
    };
}

fn homeHandler() void {
    print("HOME HANDLER\n", .{});
}

test "Start the server" {
    var routes = [_]Route{
        .{ .path = "/home", .handler = homeHandler },
    };

    var server = Server(8000).init(&routes);
    try server.start();
}
