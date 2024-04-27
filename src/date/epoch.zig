const std = @import("std");

/// Useful for calculating days between epochs.
pub const ComptimeDate = struct {
    year: comptime_int,
    month: Month,
    day: Day,

    pub const Month = std.math.IntFittingRange(1, 12);
    pub const Day = std.math.IntFittingRange(1, 31);

    pub fn init(year: comptime_int, month: Month, day: Day) ComptimeDate {
        return .{ .year = year, .month = month, .day = day };
    }
};

pub const posix = ComptimeDate.init(1970, 1, 1);
pub const dos = ComptimeDate.init(1980, 1, 1);
pub const ios = ComptimeDate.init(2001, 1, 1);
pub const openvms = ComptimeDate.init(1858, 11, 17);
pub const windows = ComptimeDate.init(1601, 1, 1);
pub const amiga = ComptimeDate.init(1978, 1, 1);
pub const pickos = ComptimeDate.init(1967, 12, 31);
pub const gps = ComptimeDate.init(1980, 1, 6);
pub const clr = ComptimeDate.init(1, 1, 1);
pub const uefi = ComptimeDate.init(1582, 10, 15);
pub const efi = ComptimeDate.init(1900, 1, 1);

pub const unix = posix;
pub const android = posix;
pub const os2 = dos;
pub const bios = dos;
pub const vfat = dos;
pub const ntfs = windows;
pub const zos = efi;
pub const ntp = zos;
pub const jbase = pickos;
pub const aros = amiga;
pub const morphos = amiga;
pub const brew = gps;
pub const atsc = gps;
pub const go = clr;
