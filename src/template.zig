const StringHashMap = @import("std").hash_map.StringHashMap;
const Allocator = @import("std").mem.Allocator;
const cwd = @import("std").fs.cwd;
const print = @import("std").debug.print;
const split = @import("std").mem.split;
const trimZerosFromString = @import("utils.zig").trimZerosFromString;
const replace = @import("std").mem.replace;
const allocPrint = @import("std").fmt.allocPrint;
const replacementSize = @import("std").mem.replacementSize;
const isAlNum = @import("std").ascii.isAlNum;
const isSpace = @import("std").ascii.isSpace;
const isDigit = @import("std").ascii.isDigit;
const ArrayList = @import("std").ArrayList;

pub const TemplateArguments = StringHashMap([]const u8);

pub const MakePageError = error{
    UnknownVariableName,
    UnknownTemplateToken,
};

pub const Page = struct {
    data: []u8,
    outbuf: []u8,
    allocator: Allocator,
    arguments: TemplateArguments,

    const Self = @This();

    const TokenType = enum {
        OpenParen,
        CloseParen,
        Variable,
        Eql,
        Number,
    };

    const Token = struct {
        toktype: TokenType,
        text: []const u8,
    };

    pub fn init(
        allocator: Allocator,
        page_file: []const u8,
        arguments: TemplateArguments,
    ) !Self {
        const data = try cwd().readFileAlloc(allocator, page_file, 1024 * 4);
        return .{
            .data = data,
            .allocator = allocator,
            .arguments = arguments,
            .outbuf = try allocator.dupe(u8, data),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
        self.allocator.free(self.outbuf);
    }

    /// generates a Zeb HTML page with dynamic information
    /// syntax:
    /// - variable interpolation: `${some_var_name}`
    /// - blocks: `##block_type (arguments...)`
    pub fn generate(self: *Self) ![]const u8 {
        var lines = split(u8, self.data, "\n");
        while (lines.next()) |line| {
            var i: usize = 0;
            for (line) |char| {
                if (i + 1 < line.len) {
                    // variable interpolation
                    if (char == '$' and line[i + 1] == '{') {
                        i += 2; // skip `$` and `{`
                        var var_name_buf: [32]u8 = undefined;
                        @memset(&var_name_buf, 0, @sizeOf(@TypeOf(var_name_buf)));
                        var j: usize = 0;
                        while (line[i] != '}') {
                            var_name_buf[j] = line[i];
                            i += 1;
                            j += 1;
                        }
                        var clean_var_name = trimZerosFromString(&var_name_buf);
                        if (self.arguments.get(clean_var_name)) |value| {
                            const search = try allocPrint(
                                self.allocator,
                                "${{{s}}}",
                                .{clean_var_name},
                            );
                            print("{s} => {s}\n", .{ search, value });
                            const size = replacementSize(u8, self.outbuf, search, value);
                            var tmpbuf = try self.allocator.alloc(u8, size);
                            //self.outbuf = try self.allocator.realloc(self.outbuf, size + 1);
                            _ = replace(u8, self.outbuf, search, value, tmpbuf);
                            self.allocator.free(self.outbuf);
                            self.outbuf = tmpbuf;
                        } else return error.UnknownVariableName;
                    }

                    // block
                    if (char == '#' and line[i + 1] == '#') {
                        i += 2; // skip `##`
                        var block_type_name: [16]u8 = undefined;
                        var k: usize = 0;
                        while (isAlNum(line[i])) {
                            block_type_name[k] = line[i];
                            k += 1;
                            i += 1;
                        }

                        while (isSpace(line[i])) {
                            i += 1;
                        }
                        var tokens = ArrayList(Token).init(self.allocator);
                        defer tokens.deinit();
                        while (i < line.len) {
                            switch (line[i]) {
                                '(' => {
                                    try tokens.append(.{
                                        .toktype = .OpenParen,
                                        .text = "(",
                                    });
                                    i += 1;
                                    continue;
                                },
                                ')' => {
                                    try tokens.append(.{
                                        .toktype = .CloseParen,
                                        .text = ")",
                                    });
                                    i += 1;
                                    continue;
                                },
                                '$' => {
                                    i += 1;
                                    var var_name_buf: [32]u8 = undefined;
                                    var l: usize = 0;
                                    @memset(&var_name_buf, 0, @sizeOf(@TypeOf(var_name_buf)));
                                    while (isAlNum(line[i])) {
                                        var_name_buf[l] = line[i];
                                        l += 1;
                                        i += 1;
                                    }
                                    var clean_var_name = trimZerosFromString(&var_name_buf);
                                    print("{s}\n", .{clean_var_name});
                                    try tokens.append(.{
                                        .toktype = .Variable,
                                        .text = clean_var_name,
                                    });
                                    continue;
                                },
                                '=' => {
                                    try tokens.append(.{
                                        .toktype = .Eql,
                                        .text = "=",
                                    });
                                    i += 1;
                                    continue;
                                },
                                // else => return error.UnknownTemplateToken,
                                else => {
                                    // TODO: handle floating point numbers
                                    // TODO: handle string literals

                                    if (isDigit(line[i])) {
                                        // max unsigned 32 bit integer has 10 digits
                                        var numbuf: [10]u8 = undefined;
                                        @memset(&numbuf, 0, @sizeOf(@TypeOf(numbuf)));
                                        var h: usize = 0;
                                        while (isDigit(line[i])) {
                                            numbuf[h] = line[i];
                                            h += 1;
                                            i += 1;
                                        }
                                        var clean_numbuf = trimZerosFromString(&numbuf);
                                        try tokens.append(.{
                                            .toktype = .Number,
                                            .text = clean_numbuf,
                                        });
                                        continue;
                                    }
                                    i += 1;
                                    continue;
                                },
                            }
                        }
                        for (tokens.items) |token| {
                            print("token: {any}\n", .{token});
                        }
                    }
                }
                i += 1;
            }
        }
        return self.outbuf;
    }
};
