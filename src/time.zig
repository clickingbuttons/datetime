const std = @import("std");
const IntFittingRange = std.math.IntFittingRange;
pub const s_per_day = std.time.s_per_day;
const ns_per_day = s_per_day * 1_000_000_000;

/// A time of day with a subsecond field capable of holding values
/// between 0 and 10 ** `precision_`.
///
/// TimeAdvanced(0) = seconds
/// TimeAdvanced(3) = milliseconds
/// TimeAdvanced(6) = microseconds
/// TimeAdvanced(9) = nanoseconds
pub fn Advanced(decimal_precision: comptime_int) type {
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
        pub const Subsecond = IntFittingRange(0, if (decimal_precision == 0) 0 else subseconds_per_s);
        pub const DaySubseconds = IntFittingRange(0, s_per_day * subseconds_per_s);
        const IDaySubseconds = std.meta.Int(.signed, @typeInfo(DaySubseconds).int.bits + 1);

        const Self = @This();

        pub const precision = decimal_precision;
        pub const subseconds_per_s: comptime_int = std.math.powi(u32, 10, decimal_precision) catch unreachable;
        pub const subseconds_per_min = 60 * subseconds_per_s;
        pub const subseconds_per_hour = 60 * subseconds_per_min;
        pub const subseconds_per_day = 24 * subseconds_per_hour;

        pub fn init(hour: Hour, minute: Minute, second: Second, subsecond: Subsecond) Self {
            return .{ .hour = hour, .minute = minute, .second = second, .subsecond = subsecond };
        }

        pub fn now() Self {
            switch (decimal_precision) {
                0 => {
                    const day_seconds = std.math.comptimeMod(std.time.timestamp(), s_per_day);
                    return fromDaySeconds(day_seconds);
                },
                1...9 => {
                    const day_nanos = std.math.comptimeMod(std.time.nanoTimestamp(), ns_per_day);
                    const day_subseconds = @divFloor(day_nanos, subseconds_per_s / 1_000_000_000);
                    return fromDaySeconds(day_subseconds);
                },
                else => @compileError("zig's highest precision timestamp is nanoTimestamp"),
            }
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
            hours: i64 = 0,
            minutes: i64 = 0,
            seconds: i64 = 0,
            subseconds: Duration.Subseconds = 0,

            pub const Subseconds = if (precision == 0) u0 else i64;

            pub fn init(hour: i64, minute: i64, second: i64, subsecond: Duration.Subseconds) Duration {
                return Duration{ .hours = hour, .minutes = minute, .seconds = second, .subseconds = subsecond };
            }
        };

        /// Does not handle leap seconds.
        /// Returns value and how many days overflowed.
        pub fn addWithOverflow(self: Self, duration: Duration) struct { Self, i64 } {
            const fs = duration.subseconds + self.subsecond;
            const s = duration.seconds + self.second + @divFloor(@as(i64, fs), 1000);
            const m = duration.minutes + self.minute + @divFloor(s, 60);
            const h = duration.hours + self.hour + @divFloor(m, 60);
            const overflow = @divFloor(h, 24);

            return .{
                Self{
                    .subsecond = if (Duration.Subseconds == u0) 0 else std.math.comptimeMod(fs, 1000),
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

        pub fn parseRfc3339(str: []const u8) !Self {
            if (str.len < "hh:mm:ss".len) return error.Parsing;
            if (str[2] != ':' or str[5] != ':') return error.Parsing;

            const hour = try std.fmt.parseInt(Hour, str[0..2], 10);
            const minute = try std.fmt.parseInt(Minute, str[3..5], 10);
            const second = try std.fmt.parseInt(Second, str[6..8], 10);

            var subsecond: Subsecond = 0;
            if (str.len > 9 and str[8] == '.') {
                const subsecond_str = str[9..];
                // Choose largest performant type.
                // Ideally, this would allow infinite precision.
                const T = f64;
                var subsecondf = try std.fmt.parseFloat(T, subsecond_str);
                const actual_precision: T = @floatFromInt(subsecond_str.len);
                subsecondf *= std.math.pow(T, 10, precision - actual_precision);

                subsecond = @intFromFloat(subsecondf);
            }

            return .{ .hour = hour, .minute = minute, .second = second, .subsecond = subsecond };
        }

        fn fmtRfc3339(self: Self, writer: anytype) !void {
            if (self.hour > 24 or self.minute > 59 or self.second > 60) return error.Range;
            try writer.print("{d:0>2}:{d:0>2}:{d:0>2}", .{ self.hour, self.minute, self.second });
            if (self.subsecond != 0) {
                // We could trim trailing zeros here to save space.
                try writer.print(".{d}", .{self.subsecond});
            }
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) (@TypeOf(writer).Error || error{Range})!void {
            _ = options;

            if (std.mem.eql(u8, "rfc3339", fmt)) {
                try self.fmtRfc3339(writer);
            } else {
                try writer.print(
                    "Time{{ .hour = {d}, .minute = .{d}, .second = .{d} }}",
                    .{ self.hour, self.minute, self.second },
                );
            }
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

    try expectEqual(Milli.init(22, 30, 0, 0), try Milli.parseRfc3339("22:30:00"));
    try expectEqual(Milli.init(22, 30, 0, 0), try Milli.parseRfc3339("22:30:00.0000"));
    try expectEqual(Milli.init(22, 30, 20, 100), try Milli.parseRfc3339("22:30:20.1"));

    const expectError = std.testing.expectError;
    try expectError(error.InvalidCharacter, Milli.parseRfc3339("22:30:20.1a00"));
    try expectError(error.Parsing, Milli.parseRfc3339("02:00:0")); // missing second digit

    var buf: [32]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const time = Milli.init(22, 30, 20, 100);
    try time.fmtRfc3339(stream.writer());
    try std.testing.expectEqualStrings("22:30:20.100", stream.getWritten());

    stream.reset();
    const time2 = Milli.init(22, 30, 20, 100);
    try time2.fmtRfc3339(stream.writer());
    try std.testing.expectEqualStrings("22:30:20.100", stream.getWritten());
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
