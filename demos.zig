const std = @import("std");
const datetime = @import("datetime");

test "now" {
    const date = datetime.Date.now();
    std.debug.print("today's date is {rfc3339}\n", .{ date });

    const time = datetime.Time.now();
    std.debug.print("today's time is {rfc3339}\n", .{ time });

    const nanotime = datetime.time.Nano.now();
    std.debug.print("today's nanotime is {rfc3339}\n", .{ nanotime });

    const dt = datetime.DateTime.now();
    std.debug.print("today's date and time is {rfc3339}\n", .{ dt });

    const NanoDateTime = datetime.datetime.Advanced(datetime.Date, datetime.time.Nano, false);
    const ndt = NanoDateTime.now();
    std.debug.print("today's date and nanotime is {rfc3339}\n", .{ ndt });
}

test "iterator" {
    const from =  datetime.Date.now();
    const to = from.add(.{ .days = 7 });

    var i = from;
    while (i.toEpoch() < to.toEpoch()) : (i = i.add(.{ .days = 1 })) {
        std.debug.print("{s} {rfc3339}\n", .{ @tagName(i.weekday()), i });
    }
}

test "RFC 3339" {
    const d1 = try datetime.Date.parseRfc3339("2024-04-27");
    std.debug.print("d1 {rfc3339}\n", .{ d1 });

    const DateTimeOffset = datetime.datetime.Advanced(datetime.Date, datetime.time.Sec, true);
    const d2 = try DateTimeOffset.parseRfc3339("2024-04-27T13:03:23-04:00");
    std.debug.print("d2 {rfc3339}\n", .{ d2 });
}
