const print = @import("std").debug.print;
const tokenize = @import("std").mem.tokenize;
const eql = @import("std").mem.eql;
const parseFloat = @import("std").fmt.parseFloat;
const trim = @import("std").mem.trim;
const isDigit = @import("std").ascii.isDigit;
const Allocator = @import("std").mem.Allocator;
const Timestamp = @import("time.zig");
const allocPrint = @import("std").fmt.allocPrint;

/// represents an HTTP method
pub const HttpMethod = enum {
    HttpMethodPost,
    HttpMethodGet,
};

/// represents an internal error related to HTTP
pub const HttpError = error{
    UnsupprtedMethod,
    UnsupportedStatusCode,
};

/// represents HTTP Content-Type header
pub const ContentType = enum {
    TextHtml,
};

fn contentTypeToString(ct: ContentType) []const u8 {
    return switch (ct) {
        .TextHtml => "Content-Type: text/html",
    };
}
/// maps status code integer to it's corresponding name
fn statusCodeToString(status_code: u16) ![]const u8 {
    return switch (status_code) {
        // info
        100 => "Continue",
        101 => "Switching Protocols",
        // success
        200 => "OK",
        201 => "Created",
        202 => "Accepted",
        203 => "Non-Authoritative Information",
        204 => "No Content",
        205 => "Reset Content",
        206 => "Partial Content",
        // redirection
        300 => "Multiple Choices",
        301 => "Moved Permanently",
        302 => "Found",
        303 => "See Other",
        304 => "Not Modified",
        307 => "Temporary Redirect",
        308 => "Permanent Redirect",
        // client error
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not allowed",
        406 => "Not Acceptable",
        407 => "Proxy Authetication Required",
        408 => "Request Timeout",
        409 => "Conflict",
        410 => "Gone",
        411 => "Length Required",
        412 => "Precondition Failed",
        413 => "Payload Too Large",
        414 => "URI Too Long",
        415 => "Unsupported Media Type",
        416 => "Range Not Satisfiable",
        417 => "Exception Failed",
        418 => "I'm a teapot", // the most importand HTTP status
        421 => "Misdirected Request",
        426 => "Upgrade Required",
        428 => "Precondition Required",
        429 => "Too Many Requests",
        431 => "Requested Header Fields Too Large",
        451 => "Unavailable For Legal Reasons",
        // server error
        500 => "Internal Server Error",
        501 => "Not Implemented",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        504 => "Gateway Timeout",
        505 => "HTTP Version Not Supported",
        506 => "Variant Also Negotiates",
        510 => "Not Extended",
        511 => "Network Authentication Required",
        else => return error.UnsupportedStatusCode,
    };
}

pub const HttpRequestInfo = struct {
    method: HttpMethod,
    route: []const u8,
    http_version: f32,
};

pub const HttpResponseInfo = struct {
    pub const Content = struct {
        cntype: ContentType,
        encoding: []const u8,
        language: []const u8,
        location: []const u8,
        disposition: []const u8,
        md5: []const u8,
        length: usize,
    };

    pub const AccessControl = struct {
        allow_origin: []const u8,
        allow_credentials: []const u8,
        expose_headers: []const u8,
        max_age: []const u8,
        allow_methods: []const u8,
        allow_headers: []const u8,
    };

    pub const Accept = struct {
        ch: []const u8,
        patch: []const u8,
        ranges: []const u8,
    };

    pub const Connection = enum {
        Close,
        KeepAlive,
    };

    status_code: u16,
    content: Content,
    access_control: AccessControl,
    accept: Accept,
    allow: []HttpMethod,
    cache_control: u32,
    connection: Connection,
    date: Timestamp,
    server: []const u8 = "Zeb Web Server",
    textual_content: ?[]const u8,

    const Self = @This();

    /// outputs the full http response string
    /// the caller has to free the memory
    pub fn getString(
        self: *Self,
        allocator: Allocator,
    ) ![]const u8 {
        const top_line = try allocPrint(
            allocator,
            "HTTP/1.1 {} {s}\r\n" ++ "{s}\r\n" ++ "\r\n{s}",
            .{
                // top entry
                self.status_code,
                try statusCodeToString(self.status_code),
                // headers
                contentTypeToString(self.content.cntype),
                // body
                self.textual_content orelse "No Content",
            },
        );
        return top_line;
    }
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
                                    return error.UnsupportedMethod;
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
