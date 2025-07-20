const std = @import("std");
const datetime = @import("datetime");

test "now" {
    const date = datetime.Date.now();
    std.debug.print("today's date is {f}\n", .{date});

    const time = datetime.Time.now();
    std.debug.print("today's time is {f}\n", .{time});

    const nanotime = datetime.time.Nano.now();
    std.debug.print("today's nanotime is {f}\n", .{nanotime});

    const dt = datetime.DateTime.now();
    std.debug.print("today's date and time is {f}\n", .{dt});

    const NanoDateTime = datetime.datetime.Advanced(datetime.Date, datetime.time.Nano, false);
    const ndt = NanoDateTime.now();
    std.debug.print("today's date and nanotime is {f}\n", .{ndt});
}

test "iterator" {
    const from = datetime.Date.now();
    const to = from.add(.{ .days = 7 });

    var i = from;
    while (i.toEpoch() < to.toEpoch()) : (i = i.add(.{ .days = 1 })) {
        std.debug.print("{s} {f}\n", .{ @tagName(i.weekday()), i });
    }
}

test "RFC 3339" {
    const d1 = try datetime.Date.parseRfc3339("2024-04-27");
    std.debug.print("d1 {f}\n", .{d1});

    const DateTimeOffset = datetime.datetime.Advanced(datetime.Date, datetime.time.Sec, true);
    const d2 = try DateTimeOffset.parseRfc3339("2024-04-27T13:03:23-04:00");
    std.debug.print("d2 {f}\n", .{d2});
}

test "formatting options" {
    const date = datetime.Date.init(2025, .jul, 20);
    const time = datetime.time.Milli.init(15, 30, 45, 123);
    const dt = datetime.DateTime.init(2025, .jul, 20, 15, 30, 45, 0, 0);

    std.debug.print("\n=== RFC3339 Format (default with {{f}}) ===\n", .{});
    std.debug.print("Date: {f}\n", .{date});
    std.debug.print("Time: {f}\n", .{time});
    std.debug.print("DateTime: {f}\n", .{dt});

    std.debug.print("\n=== Struct Format (for debugging) ===\n", .{});

    // To get struct format, use the formatStruct method directly
    var buf: [256]u8 = undefined;
    var writer = std.io.Writer.fixed(&buf);

    try date.formatStruct(&writer);
    std.debug.print("Date: {s}\n", .{writer.buffered()});

    writer = std.io.Writer.fixed(&buf);
    try time.formatStruct(&writer);
    std.debug.print("Time: {s}\n", .{writer.buffered()});

    writer = std.io.Writer.fixed(&buf);
    try dt.formatStruct(&writer);
    std.debug.print("DateTime: {s}\n", .{writer.buffered()});
}
