//! World standard calar.
//!
//! Introduced in 1582 as a revision of the Julian calendar.
const std = @import("std");
const epoch_mod = @import("./epoch.zig");
const IntFittingRange = std.math.IntFittingRange;
const s_per_day = std.time.s_per_day;
const expectEqual = std.testing.expectEqual;
const assert = std.debug.assert;

/// A date on the proleptic (projected backwards) Gregorian calendar.
pub fn Advanced(comptime YearT: type, comptime epoch: Comptime, shift: comptime_int) type {
    return struct {
        year: Year,
        month: MonthT,
        day: DayT,

        pub const Year = YearT;
        pub const Month = MonthT;
        pub const Day = DayT;

        /// Inclusive.
        pub const min_epoch_day = epoch.daysUntil(Comptime.init(std.math.minInt(Year), 1, 1));
        /// Inclusive.
        pub const max_epoch_day = epoch.daysUntil(Comptime.init(std.math.maxInt(Year), 12, 31));

        pub const EpochDays = IntFittingRange(min_epoch_day, max_epoch_day);
        // These are used for math that should not overflow.
        const UEpochDays = std.meta.Int(
            .unsigned,
            std.math.ceilPowerOfTwoAssert(u16, @typeInfo(EpochDays).int.bits),
        );
        const IEpochDays = std.meta.Int(.signed, @typeInfo(UEpochDays).int.bits);
        const EpochDaysWide = std.meta.Int(
            @typeInfo(EpochDays).int.signedness,
            @typeInfo(UEpochDays).int.bits,
        );

        pub const zig_epoch_offset = epoch_mod.zig.daysUntil(epoch);
        // Variables in paper.
        const K = Computational.epoch_.daysUntil(epoch) + era.days * shift;
        const L = era.years * shift;

        // Type overflow checks
        comptime {
            const min_year_no_overflow = -L;
            const max_year_no_overflow = std.math.maxInt(UEpochDays) / days_in_year.numerator - L + 1;
            assert(min_year_no_overflow < std.math.minInt(Year));
            assert(max_year_no_overflow > std.math.maxInt(Year));

            const min_epoch_day_no_overflow = -K;
            const max_epoch_day_no_overflow = (std.math.maxInt(UEpochDays) - 3) / 4 - K;
            assert(min_epoch_day_no_overflow < min_epoch_day);
            assert(max_epoch_day_no_overflow > max_epoch_day);
        }

        /// Easier to count from. See section 4 of paper.
        const Computational = struct {
            year: UEpochDays,
            month: UIntFitting(14),
            day: UIntFitting(30),

            pub const epoch_ = Comptime.init(0, 3, 1);

            inline fn toGregorian(self: Computational, N_Y: UIntFitting(365)) Self {
                const last_day_of_jan = 306;
                const J: UEpochDays = if (N_Y >= last_day_of_jan) 1 else 0;

                const month: MonthInt = if (J != 0) self.month - 12 else self.month;
                const year: EpochDaysWide = @bitCast(self.year +% J -% L);

                return .{
                    .year = @intCast(year),
                    .month = @enumFromInt(month),
                    .day = @as(DayT, self.day) + 1,
                };
            }

            inline fn fromGregorian(date: Self) Computational {
                const month: UIntFitting(14) = date.month.numeric();
                const Widened = std.meta.Int(
                    @typeInfo(Year).int.signedness,
                    @typeInfo(UEpochDays).int.bits,
                );
                const widened: Widened = date.year;
                const Y_G: UEpochDays = @bitCast(widened);
                const J: UEpochDays = if (month <= 2) 1 else 0;

                return .{
                    .year = Y_G +% L -% J,
                    .month = if (J != 0) month + 12 else month,
                    .day = date.day - 1,
                };
            }
        };

        const Self = @This();

        pub fn init(year: Year, month: MonthT, day: DayT) Self {
            return .{ .year = year, .month = month, .day = day };
        }

        pub fn now() Self {
            const epoch_days = @divFloor(std.time.timestamp(), s_per_day);
            return fromEpoch(@intCast(epoch_days + zig_epoch_offset));
        }

        pub fn fromEpoch(days: EpochDays) Self {
            // This function is Figure 12 of the paper.
            // Besides being ported from C++, the following has changed:
            // - Seperate Year and UEpochDays types
            // - Rewrite EAFs in terms of `a` and `b`
            // - Add EAF bounds assertions
            // - Use bounded int types provided in Section 10 instead of u32 and u64
            // - Add computational calendar struct type
            // - Add comments referencing some proofs
            assert(days >= min_epoch_day);
            assert(days <= max_epoch_day);
            const mod = std.math.comptimeMod;
            const div = comptimeDivFloor;

            const widened: EpochDaysWide = days;
            const N = @as(UEpochDays, @bitCast(widened)) +% K;

            const a1 = 4;
            const b1 = 3;
            const N_1 = a1 * N + b1;
            const C = N_1 / era.days;
            const N_C: UIntFitting(36_564) = div(mod(N_1, era.days), a1);

            const N_2 = a1 * @as(UIntFitting(146_099), N_C) + b1;
            // n % 1461 == 2939745 * n % 2^32 / 2939745,
            // for all n in [0, 28825529)
            assert(N_2 < 28_825_529);
            const a2 = 2_939_745;
            const b2 = 0;
            const P_2_max = 429493804755;
            const P_2 = a2 * @as(UIntFitting(P_2_max), N_2) + b2;
            const Z: UIntFitting(99) = div(P_2, (1 << 32));
            const N_Y: UIntFitting(365) = div(mod(P_2, (1 << 32)), a2 * a1);

            // (5 * n + 461) / 153 == (2141 * n + 197913) /2^16,
            // for all n in [0, 734)
            assert(N_Y < 734);
            const a3 = 2_141;
            const b3 = 197_913;
            const N_3 = a3 * @as(UIntFitting(979_378), N_Y) + b3;

            const computational = Computational{
                .year = 100 * C + Z,
                .month = div(N_3, 1 << 16),
                .day = div(mod(N_3, (1 << 16)), a3),
            };

            return computational.toGregorian(N_Y);
        }

        pub fn toEpoch(self: Self) EpochDays {
            // This function is Figure 13 of the paper.
            const c = Computational.fromGregorian(self);
            const C = c.year / 100;

            const y_star = days_in_year.numerator * c.year / 4 - C + C / 4;
            const days_in_5mo = 31 + 30 + 31 + 30 + 31;
            const m_star = (days_in_5mo * @as(UEpochDays, c.month) - 457) / 5;
            const N = y_star + m_star + c.day;

            return @intCast(@as(IEpochDays, @bitCast(N)) - K);
        }

        pub const Duration = struct {
            years: Year = 0,
            months: Duration.Months = 0,
            days: Duration.Days = 0,

            pub const Days = std.meta.Int(.signed, @typeInfo(EpochDays).int.bits);
            pub const Months = std.meta.Int(.signed, @typeInfo(Duration.Days).int.bits - std.math.log2_int(u16, 12));

            pub fn init(years: Year, months: Duration.Months, days: Duration.Days) Duration {
                return Duration{ .years = years, .months = months, .days = days };
            }
        };

        pub fn add(self: Self, duration: Duration) Self {
            const m = duration.months + self.month.numeric() - 1;
            const y = self.year + duration.years + @divFloor(m, 12);

            const ym_epoch_day = Self{
                .year = @intCast(y),
                .month = @enumFromInt(std.math.comptimeMod(m, 12) + 1),
                .day = 1,
            };

            var epoch_days = ym_epoch_day.toEpoch();
            epoch_days += duration.days + self.day - 1;

            return fromEpoch(epoch_days);
        }

        pub const Weekday = WeekdayT;
        pub fn weekday(self: Self) Weekday {
            const epoch_days = self.toEpoch() +% epoch.weekday().numeric() -% 1;
            return @enumFromInt(std.math.comptimeMod(epoch_days, 7) +% 1);
        }

        pub fn parseRfc3339(str: *const [10]u8) !Self {
            if (str[4] != '-' or str[7] != '-') return error.Parsing;

            const year = try std.fmt.parseInt(IntFittingRange(0, 9999), str[0..4], 10);
            const month = try std.fmt.parseInt(Month.Int, str[5..7], 10);
            if (month < 1 or month > 12) return error.Parsing;
            const m: Month = @enumFromInt(month);
            const day = try std.fmt.parseInt(Day, str[8..10], 10);
            if (day < 1 or day > m.days(isLeap(year))) return error.Parsing;

            return .{
                .year = @intCast(year), // if YearT is `i8` or `u8` this may fail. increase it to not fail.
                .month = m,
                .day = day,
            };
        }

        fn fmtRfc3339(self: Self, writer: anytype) !void {
            if (self.year < 0 or self.year > 9999) return error.Range;
            if (self.day < 1 or self.day > 99) return error.Range;
            if (self.month.numeric() < 1 or self.month.numeric() > 12) return error.Range;
            try writer.print("{d:0>4}-{d:0>2}-{d:0>2}", .{
                @as(IntFittingRange(0, 9999), @intCast(self.year)),
                self.month.numeric(),
                self.day,
            });
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
                    "Date{{ .year = {d}, .month = .{s}, .day = .{d} }}",
                    .{ self.year, @tagName(self.month), self.day },
                );
            }
        }
    };
}

pub fn Gregorian(comptime Year: type, comptime epoch: Comptime) type {
    const shift = solveShift(Year, epoch) catch unreachable;
    return Advanced(Year, epoch, shift);
}

fn testFromToEpoch(comptime T: type) !void {
    const d1 = T{ .year = 1970, .month = .jan, .day = 1 };
    const d2 = T{ .year = 1980, .month = .jan, .day = 1 };

    try expectEqual(3_652, d2.toEpoch() - d1.toEpoch());

    // We don't have time to test converting there and back again for every possible i64/u64.
    // The paper has already proven it and written tests for i32 and u32.
    // Instead let's cycle through the first and last 1 << 16 part of each range.
    const min_epoch_day: i128 = T.min_epoch_day;
    const max_epoch_day: i128 = T.max_epoch_day;
    const diff = max_epoch_day - min_epoch_day;
    const range: usize = if (max_epoch_day - min_epoch_day > 1 << 16) 1 << 16 else @intCast(diff);
    for (0..range) |i| {
        const ii: T.IEpochDays = @intCast(i);

        const d3: T.EpochDays = @intCast(min_epoch_day + ii);
        try expectEqual(d3, T.fromEpoch(d3).toEpoch());

        const d4: T.EpochDays = @intCast(max_epoch_day - ii);
        try expectEqual(d4, T.fromEpoch(d4).toEpoch());
    }
}

test "Gregorian from and to epoch" {
    try testFromToEpoch(Gregorian(i16, epoch_mod.unix));
    try testFromToEpoch(Gregorian(i32, epoch_mod.unix));
    try testFromToEpoch(Gregorian(i64, epoch_mod.unix));
    try testFromToEpoch(Gregorian(u16, epoch_mod.unix));
    try testFromToEpoch(Gregorian(u32, epoch_mod.unix));
    try testFromToEpoch(Gregorian(u64, epoch_mod.unix));

    try testFromToEpoch(Gregorian(i16, epoch_mod.windows));
    try testFromToEpoch(Gregorian(i32, epoch_mod.windows));
    try testFromToEpoch(Gregorian(i64, epoch_mod.windows));
    try testFromToEpoch(Gregorian(u16, epoch_mod.windows));
    try testFromToEpoch(Gregorian(u32, epoch_mod.windows));
    try testFromToEpoch(Gregorian(u64, epoch_mod.windows));
}

test Gregorian {
    const T = Gregorian(i16, epoch_mod.unix);
    const d1 = T.init(1960, .jan, 1);
    const epoch = T.init(1970, .jan, 1);

    try expectEqual(365, T.init(1971, .jan, 1).toEpoch());
    try expectEqual(epoch, T.fromEpoch(0));
    try expectEqual(3_653, epoch.toEpoch() - d1.toEpoch());

    // overflow
    // $ TZ=UTC0 date -d '1970-01-01 +1 year +13 months +32 days' --iso-8601=seconds
    try expectEqual(
        T.init(1972, .mar, 4),
        T.init(1970, .jan, 1).add(T.Duration.init(1, 13, 32)),
    );
    // underflow
    // $ TZ=UTC0 date -d '1972-03-04 -10 year -13 months -32 days' --iso-8601=seconds
    try expectEqual(
        T.init(1961, .jan, 3),
        T.init(1972, .mar, 4).add(T.Duration.init(-10, -13, -32)),
    );

    // $ date -d '1970-01-01'
    try expectEqual(.thu, epoch.weekday());
    try expectEqual(.thu, epoch.add(T.Duration.init(0, 0, 7)).weekday());
    try expectEqual(.thu, epoch.add(T.Duration.init(0, 0, -7)).weekday());
    // $ date -d '1980-01-01'
    try expectEqual(.tue, T.init(1980, .jan, 1).weekday());
    // $ date -d '1960-01-01'
    try expectEqual(.fri, d1.weekday());

    try expectEqual(d1, try T.parseRfc3339("1960-01-01"));
    try std.testing.expectError(error.Parsing, T.parseRfc3339("2000T01-01"));
    try std.testing.expectError(error.InvalidCharacter, T.parseRfc3339("2000-01-AD"));

    var buf: [32]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try d1.fmtRfc3339(stream.writer());
    try std.testing.expectEqualStrings("1960-01-01", stream.getWritten());
}

const WeekdayInt = IntFittingRange(1, 7);
pub const WeekdayT = enum(WeekdayInt) {
    mon = 1,
    tue = 2,
    wed = 3,
    thu = 4,
    fri = 5,
    sat = 6,
    sun = 7,

    pub const Int = WeekdayInt;

    /// Convenient conversion to `WeekdayInt`. mon = 1, sun = 7
    pub fn numeric(self: @This()) Int {
        return @intFromEnum(self);
    }
};

const MonthInt = IntFittingRange(1, 12);
pub const MonthT = enum(MonthInt) {
    jan = 1,
    feb = 2,
    mar = 3,
    apr = 4,
    may = 5,
    jun = 6,
    jul = 7,
    aug = 8,
    sep = 9,
    oct = 10,
    nov = 11,
    dec = 12,

    pub const Int = MonthInt;
    pub const Days = IntFittingRange(28, 31);

    /// Convenient conversion to `MonthInt`. jan = 1, dec = 12
    pub fn numeric(self: @This()) Int {
        return @intFromEnum(self);
    }

    pub fn days(self: @This(), is_leap_year: bool) Days {
        const m: Days = @intCast(self.numeric());
        return if (m != 2)
            30 | (m ^ (m >> 3))
        else if (is_leap_year)
            29
        else
            28;
    }
};
pub const DayT = IntFittingRange(1, 31);

test MonthT {
    try expectEqual(31, MonthT.jan.days(false));
    try expectEqual(29, MonthT.feb.days(true));
    try expectEqual(28, MonthT.feb.days(false));
    try expectEqual(31, MonthT.mar.days(false));
    try expectEqual(30, MonthT.apr.days(false));
    try expectEqual(31, MonthT.may.days(false));
    try expectEqual(30, MonthT.jun.days(false));
    try expectEqual(31, MonthT.jul.days(false));
    try expectEqual(31, MonthT.aug.days(false));
    try expectEqual(30, MonthT.sep.days(false));
    try expectEqual(31, MonthT.oct.days(false));
    try expectEqual(30, MonthT.nov.days(false));
    try expectEqual(31, MonthT.dec.days(false));
}

pub fn isLeap(year: anytype) bool {
    return if (@mod(year, 25) != 0)
        year & (4 - 1) == 0
    else
        year & (16 - 1) == 0;
}

test isLeap {
    try expectEqual(false, isLeap(2095));
    try expectEqual(true, isLeap(2096));
    try expectEqual(false, isLeap(2100));
    try expectEqual(true, isLeap(2400));
}

/// Useful for epoch math.
pub const Comptime = struct {
    year: comptime_int,
    month: Month,
    day: Day,

    pub const Month = std.math.IntFittingRange(1, 12);
    pub const Day = std.math.IntFittingRange(1, 31);

    pub fn init(year: comptime_int, month: Month, day: Day) Comptime {
        return .{ .year = year, .month = month, .day = day };
    }

    pub fn daysUntil(from: Comptime, to: Comptime) comptime_int {
        @setEvalBranchQuota(5000);
        const eras = @divFloor(to.year - from.year, era.years);
        comptime var res: comptime_int = eras * era.days;

        var i = from.year + eras * era.years;
        while (i < to.year) : (i += 1) {
            res += if (isLeap(i)) 366 else 365;
        }

        res += @intCast(daysSinceJan01(to));
        res -= @intCast(daysSinceJan01(from));

        return res;
    }

    fn daysSinceJan01(d: Comptime) u16 {
        const leap = isLeap(d.year);
        var res: u16 = d.day - 1;
        for (1..d.month) |j| {
            const m: MonthT = @enumFromInt(j);
            res += m.days(leap);
        }

        return res;
    }

    pub fn weekday(d: Comptime) WeekdayT {
        // 1970-01-01 is a Thursday.
        const known_date = epoch_mod.unix;
        const known_date_weekday: comptime_int = @intFromEnum(WeekdayT.thu);
        const start_of_week: comptime_int = @intFromEnum(WeekdayT.mon);

        const epoch_days = known_date.daysUntil(d) +% known_date_weekday -% start_of_week;
        return @enumFromInt(std.math.comptimeMod(epoch_days, 7) +% start_of_week);
    }
};

test Comptime {
    try expectEqual(1, Comptime.init(2000, 1, 1).daysUntil(Comptime.init(2000, 1, 2)));
    try expectEqual(366, Comptime.init(2000, 1, 1).daysUntil(Comptime.init(2001, 1, 1)));
    try expectEqual(146_097, Comptime.init(0, 1, 1).daysUntil(Comptime.init(400, 1, 1)));
    try expectEqual(146_097 + 366, Comptime.init(0, 1, 1).daysUntil(Comptime.init(401, 1, 1)));
    const from = Comptime.init(std.math.minInt(i16), 1, 1);
    const to = Comptime.init(std.math.maxInt(i16) + 1, 1, 1);
    try expectEqual(23_936_532, from.daysUntil(to));

    try expectEqual(WeekdayT.thu, Comptime.init(1970, 1, 1).weekday());
    const d1 = Comptime.init(2024, 4, 27);
    try expectEqual(19_840, epoch_mod.unix.daysUntil(d1));
    try expectEqual(WeekdayT.sat, d1.weekday());

    try expectEqual(WeekdayT.wed, Comptime.init(1969, 12, 31).weekday());
    const d2 = Comptime.init(1960, 1, 1);
    try expectEqual(-3653, epoch_mod.unix.daysUntil(d2));
    try expectEqual(WeekdayT.fri, d2.weekday());
}

/// The Gregorian calendar repeats every 400 years.
const era = struct {
    pub const years = 400;
    pub const days = 146_097;
};

/// Number of days between two consecutive March equinoxes
const days_in_year = struct {
    const actual = 365.2424;
    // .0001 days per year of error.
    const numerator = 1_461;
    const denominator = 4;
};

fn UIntFitting(to: comptime_int) type {
    return IntFittingRange(0, to);
}

/// Finds minimum epoch shift that covers the range:
/// [std.math.minInt(Year), std.math.maxInt(Year)]
fn solveShift(comptime Year: type, comptime epoch: Comptime) !comptime_int {
    // TODO: linear system of equations solver
    _ = epoch;
    return @divFloor(std.math.maxInt(Year), era.years) + 1;
}

test solveShift {
    const epoch = epoch_mod.unix;
    try expectEqual(82, try solveShift(i16, epoch));
    try expectEqual(5_368_710, try solveShift(i32, epoch));
    try expectEqual(23_058_430_092_136_940, try solveShift(i64, epoch));
}

fn ComptimeDiv(comptime Num: type, comptime divisor: comptime_int) type {
    const info = @typeInfo(Num).int;
    return std.meta.Int(info.signedness, info.bits - std.math.log2(divisor));
}

/// Return the quotient of `num` with the smallest integer type
fn comptimeDivFloor(num: anytype, comptime divisor: comptime_int) ComptimeDiv(@TypeOf(num), divisor) {
    return @intCast(@divFloor(num, divisor));
}

test comptimeDivFloor {
    try std.testing.expectEqual(@as(u13, 100), comptimeDivFloor(@as(u16, 1000), 10));
}
