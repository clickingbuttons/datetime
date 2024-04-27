const std = @import("std");
const date_mod = @import("./date.zig");
const time_mod = @import("./time.zig");
const epoch_mod = date_mod.epoch;
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
        const subseconds_per_day = s_per_day * Time.subseconds_per_s;

        pub fn init(year: Date.Year, month: Date.Month, day: Date.Day, hour: Time.Hour, minute: Time.Minute, second: Time.Second, subsecond: Time.Subsecond) Self {
            return .{
                .date = Date.init(year, month, day),
                .time = Time.init(hour, minute, second, subsecond),
            };
        }

        pub fn now() Self {
            return switch (Time.precision) {
                0 => fromEpoch(@intCast(std.time.timestamp())),
                else => fromEpoch(@intCast(@divFloor(std.time.nanoTimestamp(), Time.subseconds_per_s / 1_000_000_000))),
            };
        }

        /// New date time from fractional seconds since `Date.epoch`.
        pub fn fromEpoch(subseconds: EpochSubseconds) Self {
            const days = @divFloor(subseconds, subseconds_per_day);
            const new_date = Date.fromEpoch(@intCast(days));
            const day_seconds = std.math.comptimeMod(subseconds, subseconds_per_day);
            const new_time = Time.fromDaySeconds(day_seconds);
            return .{ .date = new_date, .time = new_time };
        }

        /// Returns fractional seconds since `Date.epoch`.
        pub fn toEpoch(self: Self) EpochSubseconds {
            var res: EpochSubseconds = 0;
            res += @as(EpochSubseconds, self.date.toEpoch()) * subseconds_per_day;
            res += self.time.toDaySeconds();
            return res;
        }

        pub const Duration = struct {
            years: Date.Year = 0,
            months: Date.Duration.Months = 0,
            days: Date.Duration.Days = 0,
            hours: i64 = 0,
            minutes: i64 = 0,
            seconds: i64 = 0,
            subseconds: Time.Duration.Subseconds = 0,

            pub fn init(
                years: Date.Year,
                months: Date.Duration.Months,
                days: Date.Duration.Days,
                hours: i64,
                minutes: i64,
                seconds: i64,
                subseconds: Time.Duration.Subseconds,
            ) Duration {
                return Duration{
                    .years = years,
                    .months = months,
                    .days = days,
                    .hours = hours,
                    .minutes = minutes,
                    .seconds = seconds,
                    .subseconds = subseconds,
                };
            }
        };

        pub fn add(self: Self, duration: Duration) Self {
            const time = self.time.addWithOverflow(.{
                .hours = duration.hours,
                .minutes = duration.minutes,
                .seconds = duration.seconds,
            });
            const date = self.date.add(.{
                .years = duration.years,
                .months = duration.months,
                .days = duration.days + @as(Date.Duration.Days, @intCast(time[1])),
            });
            return .{ .date = date, .time = time[0] };
        }
    };
}

test Advanced {
    const T = Advanced(date_mod.Date, time_mod.Sec);
    const a = T.init(1970, .jan, 1, 0, 0, 0, 0);
    const duration = T.Duration.init(1, 1, 1, 25, 1, 1, 0);
    try std.testing.expectEqual(T.init(1971, .feb, 3, 1, 1, 1, 0), a.add(duration));
}
