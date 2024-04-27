//! Gregorian calendars.
pub const gregorian = @import("./date/gregorian.zig");
pub const epoch = @import("./date/epoch.zig");

pub const Date = Gregorian(i16, epoch.posix);
pub const Gregorian = gregorian.Gregorian;
pub const GregorianAdvanced = gregorian.Advanced;

test {
    _ = gregorian;
    _ = epoch;
}
