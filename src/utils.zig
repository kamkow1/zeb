const trim = @import("std").mem.trim;

pub fn trimZerosFromString(string: []const u8) []const u8 {
    return trim(u8, string, &[_]u8{0});
}
