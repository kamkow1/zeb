const network = @import("network");
const print = @import("std").debug.print;
const HttpParser = @import("http.zig").HttpParser;
const eql = @import("std").mem.eql;
const ArenaAllocator = @import("std").heap.ArenaAllocator;
const page_allocator = @import("std").heap.page_allocator;
const HttpRequestInfo = @import("http.zig").HttpRequestInfo;

pub const Route = struct {
    path: []const u8,
    handler: *const fn (req: HttpRequestInfo) []const u8,
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
                _ = try client.receive(&buffer);

                var arena = ArenaAllocator.init(page_allocator);
                defer arena.deinit();
                const arenaAllocator = arena.allocator();
                var httpParser = HttpParser.init(arenaAllocator, &buffer);
                const http_info = try httpParser.parse();
                for (self.routes) |route| {
                    // found matching route
                    if (eql(u8, route.path, http_info.route)) {
                        // call the handler
                        const response = route.handler(http_info);
                        _ = try client.send(response);
                    }
                }
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

fn homeHandler(req: HttpRequestInfo) []const u8 {
    print(
        "home handler, route: {s}, method: {any}\n",
        .{ req.route, req.method },
    );

    const text = "Hello world\n";
    return text;
}

test {
    var routes = [_]Route{
        .{ .path = "/home", .handler = homeHandler },
    };

    var server = Server(8000).init(&routes);
    try server.start();
}
