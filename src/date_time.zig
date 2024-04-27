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

        pub fn init(year: Date.Year, month: Date.Month, day: Date.Day, hour: Time.Hour, minute: Time.Minute, second: Time.Second, subsecond: Time.Subsecond) Self {
            return .{
                .date = Date.init(year, month, day),
                .time = Time.init(hour, minute, second, subsecond),
            };
        }

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

        pub const Duration = struct {
            date: Date.Duration,
            time: Time.Duration,
        };

        pub fn add(
            self: Self,
            duration: Duration,
        ) Self {
            const time = self.time.addWithOverflow(duration.time);
            var duration_date = duration.date;
            duration_date.day += @intCast(time[1]);
            const date = self.date.add(duration_date);
            return .{ .date = date, .time = time[0] };
        }
    };
}

test Advanced {
    const T = Advanced(date_mod.Date, time_mod.Sec);
    const a = T.init(1970, .jan, 1, 0, 0, 0, 0);
    const duration = T.Duration{
        .date = T.Date.Duration.init(1, 1, 1),
        .time = T.Time.Duration.init(25, 1, 1, 0),
    };
    try std.testing.expectEqual(T.init(1971, .feb, 3, 1, 1, 1, 0), a.add(duration));
}
