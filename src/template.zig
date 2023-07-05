const StringHashMap = @import("std").hash_map.StringHashMap;
const Allocator = @import("std").mem.Allocator;
const cwd = @import("std").fs.cwd;
const print = @import("std").debug.print;
const split = @import("std").mem.split;
const trimZerosFromString = @import("utils.zig").trimZerosFromString;
const replace = @import("std").mem.replace;
const allocPrint = @import("std").fmt.allocPrint;
const replacementSize = @import("std").mem.replacementSize;

pub const TemplateArguments = StringHashMap([]const u8);

pub const MakePageError = error{
    UnknownVariableName,
};

pub const Page = struct {
    data: []u8,
    outbuf: []u8,
    allocator: Allocator,
    arguments: TemplateArguments,

    const Self = @This();

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

    pub fn generate(self: *Self) ![]const u8 {
        // var outbuf allocator.alloc();

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
                        } else {
                            return error.UnknownVariableName;
                        }
                    }
                }
                i += 1;
            }
        }
        return self.outbuf;
    }
};
