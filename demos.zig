const std = @import("std");
const datetime = @import("datetime");

test "now" {
    const date = datetime.Date.now();
    std.debug.print("date {}\n", .{ date });

    const time = datetime.Time.now();
    std.debug.print("time {}\n", .{ time });

    const nanotime = datetime.time.Nano.now();
    std.debug.print("nanotime {}\n", .{ nanotime });

    const dt = datetime.DateTime.now();
    std.debug.print("datetime {}\n", .{ dt });

    const NanoDateTime = datetime.datetime.Advanced(datetime.Date, datetime.time.Nano);
    const ndt = NanoDateTime.now();
    std.debug.print("nano datetime {}\n", .{ ndt });
}

test "iterator" {
    const from =  datetime.Date.now();
    const to = from.add(.{ .days = 7 });

    var i = from;
    while (i.toEpoch() < to.toEpoch()) : (i = i.add(.{ .days = 1 })) {
        std.debug.print("{d}-{d:0>2}-{d:0>2} {s}\n", .{
            i.year,
            i.month.numeric(),
            i.day,
            @tagName(i.weekday()),
        });
    }
}
