const std = @import("std");
const date_mod = @import("./date.zig");
const time_mod = @import("./time.zig");
const epoch_mod = date_mod.epoch;
const s_per_day = time_mod.s_per_day;
const s_per_hour = std.time.s_per_hour;
const s_per_min = std.time.s_per_min;

pub fn Advanced(comptime DateT: type, comptime TimeT: type, comptime has_offset: bool) type {
    return struct {
        date: Date,
        time: Time = .{},
        offset: OffsetSeconds = 0,

        pub const Date = DateT;
        pub const Time = TimeT;
        pub const OffsetSeconds = if (has_offset) std.math.IntFittingRange(-s_per_day / 2, s_per_day / 2) else u0;
        /// Fractional epoch seconds based on `TimeT.precision`:
        ///   0 = seconds
        ///   3 = milliseconds
        ///   6 = microseconds
        ///   9 = nanoseconds
        pub const EpochSubseconds = std.meta.Int(
            @typeInfo(Date.EpochDays).int.signedness,
            @typeInfo(Date.EpochDays).int.bits + std.math.log2_int_ceil(usize, Time.subseconds_per_day),
        );

        const Self = @This();
        const subseconds_per_day = s_per_day * Time.subseconds_per_s;

        pub fn init(
            year: Date.Year,
            month: Date.Month,
            day: Date.Day,
            hour: Time.Hour,
            minute: Time.Minute,
            second: Time.Second,
            subsecond: Time.Subsecond,
            offset: OffsetSeconds,
        ) Self {
            return .{
                .date = Date.init(year, month, day),
                .time = Time.init(hour, minute, second, subsecond),
                .offset = offset,
            };
        }

        pub fn now() Self {
            return switch (Time.precision) {
                0 => fromEpoch(@intCast(std.time.timestamp())),
                3 => fromEpoch(@intCast(@divFloor(std.time.milliTimestamp(), Time.subseconds_per_s / 1_000))),
                6 => fromEpoch(@intCast(@divFloor(std.time.microTimestamp(), Time.subseconds_per_s / 1_000_000))),
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
            res += @as(EpochSubseconds, self.offset) * subseconds_per_day;
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

        pub fn parseRfc3339(str: []const u8) !Self {
            if (str.len < "yyyy-MM-ddThh:mm:ssZ".len) return error.Parsing;
            if (std.ascii.toUpper(str[10]) != 'T') return error.Parsing;

            const date = try Date.parseRfc3339(str[0..10]);
            const time_end = std.mem.indexOfAnyPos(u8, str, 11, &[_]u8{ 'Z', '+', '-' }) orelse
                return error.Parsing;
            const time = try Time.parseRfc3339(str[11..time_end]);

            var offset: OffsetSeconds = 0;
            if (comptime has_offset) brk: {
                var i = time_end;
                const sign: OffsetSeconds = switch (str[i]) {
                    'Z' => break :brk,
                    '-' => -1,
                    '+' => 1,
                    else => return error.Parsing,
                };
                i += 1;

                const offset_hour = try std.fmt.parseInt(OffsetSeconds, str[i..][0..2], 10);
                if (str[i + 2] != ':') return error.Parsing;
                const offset_minute = try std.fmt.parseInt(OffsetSeconds, str[i + 3 ..][0..2], 10);

                offset = sign * (offset_hour * s_per_hour + offset_minute * s_per_min);
            }

            return .{ .date = date, .time = time, .offset = offset };
        }

        fn fmtRfc3339(self: Self, writer: anytype) !void {
            try writer.print("{rfc3339}T{rfc3339}", .{ self.date, self.time });
            if (self.offset == 0) {
                try writer.writeByte('Z');
            } else {
                const hour_offset = @divTrunc(self.offset, s_per_hour);
                const minute_offset = @divTrunc(self.offset - hour_offset * s_per_hour, s_per_min);
                try writer.writeByte(if (self.offset < 0) '-' else '+');
                try writer.print("{d:0>2}:{d:0>2}", .{ @abs(hour_offset), @abs(minute_offset) });
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
                try writer.print("DateTime{{ .date = {}, .time = {} }}", .{ self.date, self.time });
            }
        }
    };
}

test Advanced {
    const T = Advanced(date_mod.Date, time_mod.Milli, true);
    const expectEqual = std.testing.expectEqual;

    const a = T.init(1970, .jan, 1, 0, 0, 0, 0, 0);
    const duration = T.Duration.init(1, 1, 1, 25, 1, 1, 0);
    try expectEqual(T.init(1971, .feb, 3, 1, 1, 1, 0, 0), a.add(duration));

    // RFC 3339 section 5.8"
    try expectEqual(T.init(1985, .apr, 12, 23, 20, 50, 520, 0), try T.parseRfc3339("1985-04-12T23:20:50.52Z"));
    try expectEqual(T.init(1996, .dec, 19, 16, 39, 57, 0, -8 * s_per_hour), try T.parseRfc3339("1996-12-19T16:39:57-08:00"));
    try expectEqual(T.init(1990, .dec, 31, 23, 59, 60, 0, 0), try T.parseRfc3339("1990-12-31T23:59:60Z"));
    try expectEqual(T.init(1990, .dec, 31, 15, 59, 60, 0, -8 * s_per_hour), try T.parseRfc3339("1990-12-31T15:59:60-08:00"));
    try expectEqual(T.init(1937, .jan, 1, 12, 0, 27, 870, 20 * s_per_min), try T.parseRfc3339("1937-01-01T12:00:27.87+00:20"));

    // negative offset 
    try expectEqual(T.init(1985, .apr, 12, 23, 20, 50, 520, -20 * s_per_min), try T.parseRfc3339("1985-04-12T23:20:50.52-00:20"));
    try expectEqual(T.init(1985, .apr, 12, 23, 20, 50, 520, -10 * s_per_hour - 20 * s_per_min), try T.parseRfc3339("1985-04-12T23:20:50.52-10:20"));

    var buf: [32]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try T.init(1937, .jan, 1, 12, 0, 27, 870, 20 * s_per_min).fmtRfc3339(stream.writer());
    try std.testing.expectEqualStrings("1937-01-01T12:00:27.870+00:20", stream.getWritten());

    // negative offset  
    stream.reset();
    try T.init(1937, .jan, 1, 12, 0, 27, 870, -20 * s_per_min).fmtRfc3339(stream.writer());
    try std.testing.expectEqualStrings("1937-01-01T12:00:27.870-00:20", stream.getWritten());

    stream.reset();
    try T.init(1937, .jan, 1, 12, 0, 27, 870, -1 * s_per_hour - 20 * s_per_min).fmtRfc3339(stream.writer());
    try std.testing.expectEqualStrings("1937-01-01T12:00:27.870-01:20", stream.getWritten());
}
