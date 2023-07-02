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

    if (eql(u8, req.headers.get("Content-Type").?, "application/json")) {
        const body = trim(u8, req.body, &[_]u8{0});
        var stream = json.TokenStream.init(body);
        const obj = try json.parse(
            UserInfo,
            &stream,
            .{ .allocator = allocator },
        );
        name = obj.name;
    }
    print("Name: {s}\n", .{name});
    return res_str;
}

test {
    var routes = [_]Route{
        .{ .path = "/home", .handler = homeHandler },
    };
    var server = Server(8000).init(&routes);
    try server.start();
}
```

# Goals
- [ ] Implement route parameters
- [ ] Create a simple templating engine