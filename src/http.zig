const eql = @import("std").mem.eql;
const Allocator = @import("std").mem.Allocator;
const Timestamp = @import("time.zig").Timestamp;
const allocPrint = @import("std").fmt.allocPrint;
const WeekDay = @import("time.zig").WeekDay;
const Month = @import("time.zig").Month;
const split = @import("std").mem.split;
const endsWith = @import("std").mem.endsWith;
const StringHashMap = @import("std").hash_map.StringHashMap;
const trimLeft = @import("std").mem.trimLeft;
const set = @import("std").mem.set;
const isASCII = @import("std").ascii.isASCII;

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

fn getShortDayName(wd: WeekDay) []const u8 {
    return switch (wd) {
        .Monday => "Mon",
        .Tuesday => "Tue",
        .Wednesday => "Wed",
        .Thursday => "Thu",
        .Friday => "Fri",
        .Saturday => "Sat",
        .Sunday => "Sun",
    };
}

fn getShortMonthName(m: Month) []const u8 {
    return switch (m) {
        .January => "Jan",
        .February => "Feb",
        .March => "Mar",
        .April => "Apr",
        .May => "May",
        .June => "Jun",
        .July => "Jul",
        .August => "Aug",
        .September => "Sep",
        .October => "Oct",
        .November => "Nov",
        .December => "Dec",
    };
}

/// creates a timestamp string (RFC 9110)
/// caller has to free the memory
pub fn getDateForHttpUtc(allocator: Allocator) ![]const u8 {
    const utc_now = Timestamp.now_utc();
    return try allocPrint(
        allocator,
        "Date: {s}, {} {s} {} {}:{}:{} UTC",
        .{
            getShortDayName(utc_now.date.week_day),
            utc_now.date.month_day,
            getShortMonthName(utc_now.date.month),
            utc_now.date.year,
            utc_now.time.hour,
            utc_now.time.minute,
            utc_now.time.second,
        },
    );
}

pub const HttpRequestInfo = struct {
    method: HttpMethod,
    route: []const u8,
    http_version: []const u8,
    headers: StringHashMap([]const u8),
    body: []u8,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.headers.deinit();
        self.allocator.free(self.route);
        self.allocator.free(self.body);
    }
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
    date: []const u8,
    server: []const u8 = "Zeb Web Server",
    textual_content: ?[]const u8,

    const Self = @This();

    /// outputs the full http response string
    /// the caller has to free the memory
    pub fn getString(
        self: *Self,
        allocator: Allocator,
    ) ![]const u8 {
        const headers = try allocPrint(
            allocator,
            "{s}\r\n{s}\r\n",
            .{
                // Content-Type
                contentTypeToString(self.content.cntype),
                // Date
                self.date,
            },
        );
        defer allocator.free(headers);

        const text_res = try allocPrint(
            allocator,
            "HTTP/1.1 {} {s}\r\n" ++ "{s}\r\n" ++ "\r\n{s}",
            .{
                // top entry
                self.status_code,
                try statusCodeToString(self.status_code),
                // headers
                headers,
                // body
                self.textual_content orelse "No Content",
            },
        );
        return text_res;
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

    /// parses the HTTP request
    /// caller has to free: HttpRequestInfo.route, HttpRequestInfo.body
    /// caller has to deinit: HttpRequestInfo.headers
    pub fn parse(self: *Self) !HttpRequestInfo {
        var req_info: HttpRequestInfo = undefined;
        // set the allocator for later self-cleanup
        req_info.allocator = self.allocator;
        var lines = split(u8, self.text, "\r\n");

        // process the top entry
        const top_entry = lines.next().?;
        var words = split(u8, top_entry, " ");
        const method = words.next().?;
        const route = words.next().?;
        const version = words.next().?;

        if (eql(u8, method, "POST")) {
            req_info.method = .HttpMethodPost;
        } else if (eql(u8, method, "GET")) {
            req_info.method = .HttpMethodGet;
        } else {
            return error.UnsupportedMethod;
        }

        req_info.route = try self.allocator.dupe(u8, route);
        req_info.http_version = version;

        // process the request
        var end_of_headers = false;
        req_info.headers = StringHashMap([]const u8).init(self.allocator);
        req_info.body = try self.allocator.alloc(u8, 2048);
        set(u8, req_info.body, 0);
        var i: usize = 0;
        while (lines.next()) |line| {
            if (line.len == 0 and !end_of_headers) {
                end_of_headers = true;
            }

            if (!end_of_headers) {
                // header line
                var data = split(u8, line, ":");
                const key = data.next().?;
                var value = data.next().?;
                value = trimLeft(u8, value, " ");
                try req_info.headers.put(key, value);
            } else {
                // body
                for (line) |char| {
                    // avoid problematic non-ascii chars
                    if (isASCII(char)) {
                        req_info.body[i] = char;
                        i += 1;
                    }
                }
            }
        }

        return req_info;
    }
};
