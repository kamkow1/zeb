const print = @import("std").debug.print;
const tokenize = @import("std").mem.tokenize;
const eql = @import("std").mem.eql;
const parseFloat = @import("std").fmt.parseFloat;
const trim = @import("std").mem.trim;
const isDigit = @import("std").ascii.isDigit;
const Allocator = @import("std").mem.Allocator;

pub const HttpMethod = enum {
    HttpMethodPost,
    HttpMethodGet,
};

pub const HttpMethodError = error{
    UnsupprtedHttpMethodError,
};

pub const HttpRequestInfo = struct {
    method: HttpMethod,
    route: []const u8,
    http_version: f32,
};

pub const HttpParser = struct {
    allocator: Allocator,
    text: []u8,

    const Self = @This();

    pub fn init(allocator: Allocator, text: []u8) Self {
        return .{
            .allocator = allocator,
            .text = text,
        };
    }

    pub fn parse(self: *Self) !HttpRequestInfo {
        var req_info: HttpRequestInfo = undefined;

        var i: usize = 0;
        var lineno: usize = 0;
        var line: [1024]u8 = undefined;
        for (self.text) |char| {
            if (char == '\r') {
                if (lineno == 0) {
                    var it = tokenize(u8, &line, " ");
                    var count: usize = 0;
                    while (it.next()) |word| {
                        switch (count) {
                            // HTTP method
                            0 => {
                                if (eql(u8, word, "POST")) {
                                    req_info.method = .HttpMethodPost;
                                } else if (eql(u8, word, "GET")) {
                                    req_info.method = .HttpMethodGet;
                                } else {
                                    return error.UnsuportedHttpMethodError;
                                }
                            },
                            // route
                            1 => {
                                req_info.route = try self.allocator.dupe(u8, word);
                            },
                            // TODO: HTTP version
                            else => {},
                        }

                        count += 1;
                    }
                }

                @memset(&line, 0, @sizeOf(@TypeOf(line)));
                i += 1;
                lineno += 1;
                continue;
            }

            line[i] = char;
            i += 1;
        }

        return req_info;
    }
};
