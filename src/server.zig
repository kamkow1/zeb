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
const json = @import("std").json;
const trim = @import("std").mem.trim;
const HttpString = @import("http.zig").HttpString;
const split = @import("std").mem.split;
const trimZerosFromString = @import("utils.zig").trimZerosFromString;

pub const Route = struct {
    path: []const u8,
    args: [][]const u8,
    handler: *const fn (
        allocator: Allocator,
        req: HttpRequestInfo,
    ) anyerror!HttpString,
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

                var http_info = try httpParser.parse();
                defer http_info.deinit();

                for (self.routes) |route| {
                    // found matching route
                    var route_iter = split(u8, http_info.route, "?");
                    const route_wo_args = route_iter.next().?;
                    if (eql(u8, route_wo_args, route.path)) {
                        // call the handler
                        var response = try route.handler(arenaAllocator, http_info);
                        defer response.deinit();
                        _ = try client.send(response.string);
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

fn homeHandler(allocator: Allocator, req: HttpRequestInfo) !HttpString {
    const UserInfo = struct {
        name: []const u8,
    };

    print(
        "home handler, route: {s}, method: {any}\n",
        .{ req.route, req.method },
    );

    const text = @embedFile(asset_dir ++ "/home.html");
    var response: HttpResponseInfo = undefined;
    response.status_code = 200;
    response.content.cntype = ContentType.TextHtml;
    response.date = try getDateForHttpUtc(allocator);
    response.textual_content = text;
    const res_str = try response.getString(allocator);

    var name: []const u8 = "User";
    // TODO: Add support for more HTTP methods
    switch (req.method) {
        .HttpMethodGet => {
            if (req.route_args.get("name")) |name_arg| {
                name = name_arg;
            }
        },
        .HttpMethodPost => {
            // check that json is sent
            // TODO: test XML
            const contentType = req.headers.get("Content-Type") orelse "";
            if (eql(u8, contentType, "application/json")) {
                const body = trimZerosFromString(req.body);
                var stream = json.TokenStream.init(body);
                const obj = try json.parse(
                    UserInfo,
                    &stream,
                    .{ .allocator = allocator },
                );
                name = obj.name;
            }
        },
    }

    print("Name: {s}\n", .{name});
    return res_str;
}

test {
    var arg_name = "name";
    var routes = [_]Route{
        .{
            .path = "/home",
            .args = &[_][]const u8{arg_name},
            .handler = homeHandler,
        },
    };
    var server = Server(8000).init(&routes);
    try server.start();
}
