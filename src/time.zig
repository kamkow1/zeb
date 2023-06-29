// original by Remy2701
// https://github.com/Remy2701/timestamp/blob/master/src/main.zig

const std = @import("std");
const c = @cImport(@cInclude("time.h"));

/// Enumeration of the week days with their corresponding day number (Monday is 1, Sunday is 7)
pub const WeekDay = enum(u8) {
    Sunday = 0,
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
};

/// Enumeration of the months with their corresponding month number (January is 1, December is 12)
pub const Month = enum(u8) { January = 1, February, March, April, May, June, July, August, September, October, November, December };

pub const Year = u16;
pub const MonthDay = u8;

/// Date structure representing a date (year, month, week day and month day)
pub const Date = struct {
    year: Year,
    month: Month,
    week_day: WeekDay,
    month_day: MonthDay,
};

pub const Hour = u8;
pub const Minute = u8;
pub const Second = u8;

/// Time structure representing a time (hour, minute and second)
pub const Time = struct {
    hour: Hour,
    minute: Minute,
    second: Second,
};

/// Timestamp structure containing the date, time and rawtime
/// The current time can be obtained using the `now_local` or `now_utc` functions
pub const Timestamp = struct {
    rawtime: i64,
    date: Date,
    time: Time,

    /// returns the Timestamp structure corresponding to the current local time and date
    pub fn now_local() Timestamp {
        const rawtime = c.time(null);
        return from_rawtime_local(rawtime);
    }

    /// returns the Timestamp structure corresponding to the local time and date of rawtime
    /// rawtime being the raw timestamp
    pub fn from_rawtime_local(rawtime: i64) Timestamp {
        const info = c.localtime(&rawtime);

        return Timestamp{ .rawtime = rawtime, .date = Date{
            .year = 1900 + @intCast(Year, info.*.tm_year),
            .month = @intToEnum(Month, info.*.tm_mon + 1),
            .week_day = @intToEnum(WeekDay, info.*.tm_wday),
            .month_day = @intCast(MonthDay, info.*.tm_mday),
        }, .time = Time{ .hour = @intCast(Hour, info.*.tm_hour), .minute = @intCast(Minute, info.*.tm_min), .second = @intCast(Second, info.*.tm_sec) } };
    }

    /// returns the Timestamp structure corresponding to the current UTC time and date
    pub fn now_utc() Timestamp {
        const rawtime = c.time(null);
        return from_rawtime_utc(rawtime);
    }

    /// returns the Timestamp structure corresponding to the UTC time and date of rawtime
    /// rawtime being the raw timestamp
    pub fn from_rawtime_utc(rawtime: i64) Timestamp {
        const info = c.gmtime(&rawtime);

        return Timestamp{ .rawtime = rawtime, .date = Date{
            .year = 1900 + @intCast(Year, info.*.tm_year),
            .month = @intToEnum(Month, info.*.tm_mon + 1),
            .week_day = @intToEnum(WeekDay, info.*.tm_wday),
            .month_day = @intCast(MonthDay, info.*.tm_mday),
        }, .time = Time{ .hour = @intCast(Hour, info.*.tm_hour), .minute = @intCast(Minute, info.*.tm_min), .second = @intCast(Second, info.*.tm_sec) } };
    }
};

/// Example of how to use the library
pub fn main() !void {
    // Get the current UTC time & date
    const utc_now = Timestamp.now_utc();
    std.debug.print("{}/{}/{} {}:{}:{}\n", .{ utc_now.date.month_day, @enumToInt(utc_now.date.month), utc_now.date.year, utc_now.time.hour, utc_now.time.minute, utc_now.time.second });

    // Get the current local time & date
    const local_now = Timestamp.now_local();
    std.debug.print("{}/{}/{} {}:{}:{}\n", .{ local_now.date.month_day, @enumToInt(local_now.date.month), local_now.date.year, local_now.time.hour, local_now.time.minute, local_now.time.second });
}

test "from_rawtime" {
    const timestamp = Timestamp.from_rawtime_utc(1444104000);
    // Testing the date
    try std.testing.expectEqual(@intCast(Year, 2015), timestamp.date.year);
    try std.testing.expectEqual(Month.October, timestamp.date.month);
    try std.testing.expectEqual(@intCast(MonthDay, 6), timestamp.date.month_day);
    try std.testing.expectEqual(WeekDay.Tuesday, timestamp.date.week_day);
    // Testing the time
    try std.testing.expectEqual(@intCast(Hour, 4), timestamp.time.hour);
    try std.testing.expectEqual(@intCast(Minute, 0), timestamp.time.minute);
    try std.testing.expectEqual(@intCast(Hour, 0), timestamp.time.second);
}
