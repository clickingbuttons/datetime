const std = @import("std");
const IntFittingRange = std.math.IntFittingRange;
pub const s_per_day = 86_400;

/// A time of day with a subsecond field capable of holding values
/// between 0 and 10 ** `precision_`.
///
/// TimeAdvanced(0) = seconds
/// TimeAdvanced(3) = milliseconds
/// TimeAdvanced(6) = microseconds
/// TimeAdvanced(9) = nanoseconds
pub fn Advanced(precision_: comptime_int) type {
    return struct {
        hour: Hour = 0,
        minute: Minute = 0,
        /// Allows leap seconds.
        second: Second = 0,
        /// Milliseconds, microseconds, or nanoseconds.
        subsecond: Subsecond = 0,

        pub const Hour = IntFittingRange(0, 23);
        pub const Minute = IntFittingRange(0, 59);
        pub const Second = IntFittingRange(0, 60);
        pub const Subsecond = IntFittingRange(0, if (precision_ == 0) 0 else subseconds_per_s);
        pub const DaySubseconds = IntFittingRange(0, s_per_day * subseconds_per_s);
        const IDaySubseconds = std.meta.Int(.signed, @typeInfo(DaySubseconds).Int.bits + 1);

        const Self = @This();

        pub const precision = precision_;
        const multiplier: comptime_int = std.math.powi(usize, 10, precision_) catch unreachable;
        pub const subseconds_per_s = multiplier;
        pub const subseconds_per_min = 60 * subseconds_per_s;
        pub const subseconds_per_hour = 60 * subseconds_per_min;
        pub const subseconds_per_day = 24 * subseconds_per_hour;

        pub fn init(hour: Hour, minute: Minute, second: Second, subsecond: Subsecond) Self {
            return .{ .hour = hour, .minute = minute, .second = second, .subsecond = subsecond };
        }

        pub fn fromDaySeconds(seconds: DaySubseconds) Self {
            var subseconds = std.math.comptimeMod(seconds, subseconds_per_day);

            const hour = @divFloor(subseconds, subseconds_per_hour);
            subseconds -= hour * subseconds_per_hour;

            const minute = @divFloor(subseconds, subseconds_per_min);
            subseconds -= minute * subseconds_per_min;

            const second = @divFloor(subseconds, subseconds_per_s);
            subseconds -= second * subseconds_per_s;

            return .{
                .hour = @intCast(hour),
                .minute = @intCast(minute),
                .second = @intCast(second),
                .subsecond = @intCast(subseconds),
            };
        }

        pub fn toDaySeconds(self: Self) DaySubseconds {
            var sec: IDaySubseconds = 0;
            sec += @as(IDaySubseconds, self.hour) * subseconds_per_hour;
            sec += @as(IDaySubseconds, self.minute) * subseconds_per_min;
            sec += @as(IDaySubseconds, self.second) * subseconds_per_s;
            sec += @as(IDaySubseconds, self.subsecond);

            return std.math.comptimeMod(sec, s_per_day * subseconds_per_s);
        }

        pub const Duration = struct {
            hour: i64 = 0,
            minute: i64 = 0,
            second: i64 = 0,
            subsecond: Duration.Subsecond = 0,

            pub const Subsecond = if (precision == 0) u0 else i64;

            /// May save some typing vs struct initialization.
            pub fn init(hour: i64, minute: i64, second: i64, subsecond: Duration.Subsecond) Duration {
                return .{ .hour = hour, .minute = minute, .second = second, .subsecond = subsecond };
            }
        };

        /// Does not handle leap seconds.
        /// Returns value and how many days overflowed.
        pub fn addWithOverflow(self: Self, duration: Duration) struct { Self, i64 } {
            const fs = duration.subsecond + self.subsecond;
            const s = duration.second + self.second + @divFloor(@as(i64, fs), 1000);
            const m = duration.minute + self.minute + @divFloor(s, 60);
            const h = duration.hour + self.hour + @divFloor(m, 60);
            const overflow = @divFloor(h, 24);

            return .{
                Self{
                    .subsecond = if (Duration.Subsecond == u0) 0 else std.math.comptimeMod(fs, 1000),
                    .second = std.math.comptimeMod(s, 60),
                    .minute = std.math.comptimeMod(m, 60),
                    .hour = std.math.comptimeMod(h, 24),
                },
                overflow,
            };
        }

        /// Does not handle leap seconds nor overflow.
        pub fn add(self: Self, duration: Duration) Self {
            return self.addWithOverflow(duration)[0];
        }
    };
}

test Advanced {
    const t1 = Milli{};
    const expectEqual = std.testing.expectEqual;
    // no overflow
    try expectEqual(Milli.init(2, 2, 2, 1), t1.add(Milli.Duration.init(2, 2, 2, 1)));
    // cause each place to overflow
    try expectEqual(
        .{ Milli.init(2, 2, 2, 1), @as(i64, 1) },
        t1.addWithOverflow(Milli.Duration.init(25, 61, 61, 1001)),
    );
    // cause each place to underflow
    try expectEqual(
        .{ Milli.init(21, 57, 57, 999), @as(i64, -2) },
        t1.addWithOverflow(Milli.Duration.init(-25, -61, -61, -1001)),
    );
}

/// Time with second precision.
pub const Sec = Advanced(0);
/// Time with millisecond precision.
pub const Milli = Advanced(3);
/// Time with microsecond precision.
/// Note: This is the same size `TimeNano`. If you want the extra precision use that instead.
pub const Micro = Advanced(6);
/// Time with nanosecond precision.
pub const Nano = Advanced(9);
