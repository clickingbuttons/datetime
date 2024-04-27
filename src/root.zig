//! Gregorian types.
const std = @import("std");
pub const epoch = @import("./date/epoch.zig");
pub const date = @import("./date.zig");
pub const time = @import("./time.zig");
const date_time = @import("./date_time.zig");

/// A Gregorian Date using days since `1970-01-01` for its epoch methods.
///
/// Supports dates between years -32_768 and 32_768.
pub const Date = date.Gregorian(i16, epoch.posix);
pub const Month = Date.Month;
pub const Day = Date.Day;
pub const Weekday = Date.Weekday;

/// A DateTime using days since `1970-01-01` for its epoch methods.
///
/// Supports dates between years -32_768 and 32_768.
/// Supports times at a second resolution.
pub const DateTime = date_time.Advanced(Date, time.Sec);

/// Tests EpochSeconds -> DateTime and DateTime -> EpochSeconds
fn testEpoch(secs: DateTime.EpochSubseconds, dt: DateTime) !void {
    const actual_dt = DateTime.fromEpoch(secs);
    try std.testing.expectEqual(dt, actual_dt);
    try std.testing.expectEqual(secs, dt.toEpoch());
}

test DateTime {
    // $ date -d @31535999 --iso-8601=seconds
    try std.testing.expectEqual(8, @sizeOf(DateTime));
    try testEpoch(0, .{ .date = .{ .year = 1970, .month = .jan, .day = 1 } });
    try testEpoch(31535999, .{
        .date = .{ .year = 1970, .month = .dec, .day = 31 },
        .time = .{ .hour = 23, .minute = 59, .second = 59 },
    });
    try testEpoch(1622924906, .{
        .date = .{ .year = 2021, .month = .jun, .day = 5 },
        .time = .{ .hour = 20, .minute = 28, .second = 26 },
    });
    try testEpoch(1625159473, .{
        .date = .{ .year = 2021, .month = .jul, .day = 1 },
        .time = .{ .hour = 17, .minute = 11, .second = 13 },
    });
    // Washington bday, proleptic
    try testEpoch(-7506041400, .{
        .date = .{ .year = 1732, .month = .feb, .day = 22 },
        .time = .{ .hour = 12, .minute = 30 },
    });
    // minimum date
    try testEpoch(-1096225401600, .{
        .date = .{ .year = std.math.minInt(i16), .month = .jan, .day = 1 },
    });
    // maximum date
    // $ date -d '32767-12-31 UTC' +%s
    try testEpoch(971890876800, .{
        .date = .{ .year = std.math.maxInt(i16), .month = .dec, .day = 31 },
    });
}

test {
    _ = date;
    _ = epoch;
    _ = time;
}
