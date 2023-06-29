const network = @import("network");
const print = @import("std").debug.print;
const HttpParser = @import("http.zig").HttpParser;
const eql = @import("std").mem.eql;
const ArenaAllocator = @import("std").heap.ArenaAllocator;
const page_allocator = @import("std").heap.page_allocator;
const HttpRequestInfo = @import("http.zig").HttpRequestInfo;
const HttpResponseInfo = @import("http.zig").HttpResponseInfo;
const Allocator = @import("std").mem.Allocator;
const ContentType = @import("http.zig").ContentType;
const getDateForHttpUtc = @import("http.zig").getDateForHttpUtc;

pub const Route = struct {
    path: []const u8,
    handler: *const fn (
        allocator: Allocator,
        req: HttpRequestInfo,
    ) []const u8,
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
                defer arenaAllocator.free(http_info.route);

                for (self.routes) |route| {
                    // found matching route
                    if (eql(u8, route.path, http_info.route)) {
                        // call the handler
                        const response = route.handler(arenaAllocator, http_info);
                        defer arenaAllocator.free(response);
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

// demo

const asset_dir = "assets";

fn homeHandler(allocator: Allocator, req: HttpRequestInfo) []const u8 {
    print(
        "home handler, route: {s}, method: {any}\n",
        .{ req.route, req.method },
    );

    const text = @embedFile(asset_dir ++ "/home.html");
    var response: HttpResponseInfo = undefined;
    response.status_code = 200;
    response.content.cntype = ContentType.TextHtml;
    response.date = getDateForHttpUtc(allocator) catch "ERROR!";
    response.textual_content = text;

    const res_str = response.getString(allocator) catch "ERROR!\n";
    print("response:\n{s}\n", .{res_str});
    return res_str;
}

test {
    var routes = [_]Route{
        .{ .path = "/home", .handler = homeHandler },
    };

    var server = Server(8000).init(&routes);
    try server.start();
}
