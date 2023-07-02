# Zeb - a Zig web framework
Zeb is a simple, minimalistic web framework that provides basic functionality
over HTTP and route handling.

# Examples
A simple example is located in `src/server.zig` in the test block.
```zig
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
    if (req.method == .HttpMethodPost) {
        // check that json is sent
        // TODO: test XML
        const contentType = req.headers.get("Content-Type") orelse "";
        if (eql(u8, contentType, "application/json")) {
            const body = trim(u8, req.body, &[_]u8{0});
            var stream = json.TokenStream.init(body);
            const obj = try json.parse(
                UserInfo,
                &stream,
                .{ .allocator = allocator },
            );
            name = obj.name;
        }
    } else if (req.method == .HttpMethodGet) {
        if (req.route_args.get("name")) |name_arg| {
            name = name_arg;
        }
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
```

# Goals
- [ ] Implement route parameters
- [ ] Create a simple templating engine
