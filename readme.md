# Zeb - a Zig web framework
Zeb is a simple, minimalistic web framework that provides basic functionality
over HTTP and route handling.

# Examples
A simple example is located in `src/server.zig` in the test block.
```zig
fn homeHandler(
    allocator: Allocator,
    req: HttpRequestInfo,
) !HttpString {
    const IncomingRequest = struct {
        name: []const u8,
        message: []const u8,
    };

    print(
        "home handler, route: {s}, method: {any}\n",
        .{ req.route, req.method },
    );

    var name: []const u8 = "User";
    var message: []const u8 = "No Message";
    // TODO: Add support for more HTTP methods
    switch (req.method) {
        .HttpMethodGet => {
            if (req.route_args.get("name")) |name_arg| {
                name = name_arg;
            }
            if (req.route_args.get("message")) |message_arg| {
                message = message_arg;
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
                    IncomingRequest,
                    &stream,
                    .{ .allocator = allocator },
                );
                name = obj.name;
                message = obj.message;
            }
        },
    }

    var args = StringHashMap([]const u8).init(allocator);
    try args.put("name", name);
    try args.put("message", message);
    defer args.deinit();
    var page = try Page.init(allocator, "src/assets/home.zebhtml", args);
    defer page.deinit();

    var response: HttpResponseInfo = undefined;
    response.status_code = 200;
    response.content.cntype = ContentType.TextHtml;
    response.date = try getDateForHttpUtc(allocator);
    response.textual_content = try page.generate();
    const res_str = try response.getString(allocator);

    return res_str;
}

test {
    var arg_name = "name";
    var arg_message = "message";
    var routes = [_]Route{
        .{
            .path = "/home",
            .args = &[_][]const u8{ arg_name, arg_message },
            .handler = homeHandler,
        },
    };
    var server = Server.init(
        testing.allocator,
        8000,
        &routes,
    );
    try server.start();
}
```

# Goals
- [x] Route handling
- [x] Implement body parameters
- [x] Implement route parameters
- [ ] Create a simple templating engine
    * [x] Variable interpolation
    * [ ] If conditions
    * [ ] Loops
