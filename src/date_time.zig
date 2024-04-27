const std = @import("std");
const date_mod = @import("./date.zig");
const time_mod = @import("./time.zig");
const s_per_day = time_mod.s_per_day;

pub fn Advanced(comptime DateT: type, comptime TimeT: type) type {
    return struct {
        date: Date,
        time: Time = .{},

        pub const Date = DateT;
        pub const Time = TimeT;
        /// Fractional epoch seconds based on `TimeT.precision`:
        ///   0 = seconds
        ///   3 = milliseconds
        ///   6 = microseconds
        ///   9 = nanoseconds
        pub const EpochSubseconds = std.meta.Int(
            @typeInfo(Date.EpochDays).Int.signedness,
            @typeInfo(Date.EpochDays).Int.bits + std.math.log2_int_ceil(usize, Time.subseconds_per_day),
        );

        const Self = @This();

        /// New date time from fractional seconds since `Date.epoch`.
        pub fn fromEpoch(subseconds: EpochSubseconds) Self {
            const days = @divFloor(subseconds, s_per_day * Time.subseconds_per_s);
            const new_date = Date.fromEpoch(@intCast(days));
            const day_seconds = std.math.comptimeMod(subseconds, s_per_day * Time.subseconds_per_s);
            const new_time = Time.fromDaySeconds(day_seconds);
            return .{ .date = new_date, .time = new_time };
        }

        /// Returns fractional seconds since `Date.epoch`.
        pub fn toEpoch(self: Self) EpochSubseconds {
            var res: EpochSubseconds = 0;
            res += @as(EpochSubseconds, self.date.toEpoch()) * s_per_day * Time.subseconds_per_s;
            res += self.time.toDaySeconds();
            return res;
        }

        pub fn add(
            self: Self,
            year: Date.Year,
            month: Date.MonthAdd,
            day: Date.IEpochDays,
            hour: i64,
            minute: i64,
            second: i64,
            subsecond: i64,
        ) Self {
            const time = self.time.addWithOverflow(hour, minute, second, subsecond);
            const date = self.date.add(year, month, day + time.day_overflow);
            return .{ .date = date, .time = time.time };
        }
    };
}
