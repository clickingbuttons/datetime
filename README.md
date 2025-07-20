# datetime

![zig-version](https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Fclickingbuttons%2Fdatetime%2Frefs%2Fheads%2Fmaster%2Fbuild.zig.zon&search=minimum_zig_version%5Cs*%3D%5Cs*%22(.*)%22&replace=%241&label=minimum%20zig%20version)
![tests](https://github.com/clickingbuttons/datetime/actions/workflows/test.yml/badge.svg)
[![docs](https://github.com/clickingbuttons/datetime/actions/workflows/publish_docs.yml/badge.svg)](https://clickingbuttons.github.io/datetime)

Generic Date, Time, and DateTime library.

## Installation
```sh
zig fetch --save "git+https://github.com/clickingbuttons/datetime.git"
# or
zig fetch --save "https://github.com/clickingbuttons/datetime/archive/refs/tags/0.14.0.tar.gz"
```

### build.zig
```zig
const datetime = b.dependency("datetime", .{
    .target = target,
    .optimize = optimize,
});
your_lib_or_exe.root_module.addImport("datetime", datetime.module("datetime"));
```

## Usage

Check out [the demos](./demos.zig). Here's a simple one:
```zig
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
```

### Formatting Options

**RFC3339 Format (default):** The `{f}` format specifier outputs RFC3339 format by default:

```zig
const date = datetime.Date.init(2025, .jul, 20);
const time = datetime.time.Milli.init(15, 30, 45, 123);
const dt = datetime.DateTime.init(2025, .jul, 20, 15, 30, 45, 0, 0);

std.debug.print("Date: {f}\n", .{date});     // Output: 2025-07-20
std.debug.print("Time: {f}\n", .{time});     // Output: 15:30:45.123
std.debug.print("DateTime: {f}\n", .{dt});   // Output: 2025-07-20T15:30:45Z
```

**Struct Format (for debugging):** Use the `formatStruct` method for debug-style output:

```zig
var buf: [256]u8 = undefined;
var writer = std.io.Writer.fixed(&buf);

try date.formatStruct(&writer);
std.debug.print("Date: {s}\n", .{writer.buffered()});
// Output: Date{ .year = 2025, .month = .jul, .day = 20 }

writer = std.io.Writer.fixed(&buf);
try time.formatStruct(&writer);
std.debug.print("Time: {s}\n", .{writer.buffered()});
// Output: Time{ .hour = 15, .minute = 30, .second = 45, .subsecond = 123 }
```

Features:
- Convert to/from epoch subseconds using world's fastest known algorithm. [^1]
- Choose your precision:
    - Date's `Year` type.
    - Time's `Subsecond` type.
    - Date's `epoch` for subsecond conversion.
    - Whether DateTime has an `OffsetSeconds` field
- Durations with addition.
- RFC3339 parsing and formatting.
- Use Comptime dates for epoch math.

In-scope, PRs welcome:
- [ ] Localization
- [ ] Leap seconds

## Why yet another date time library?
- I frequently use different precisions for years, subseconds, and UTC offsets.
- Zig standard library [does not have accepted proposal](https://github.com/ziglang/zig/issues/8396).
- Andrew [rejected this from stdlib.](https://github.com/ziglang/zig/pull/19549#issuecomment-2062091512)
- [Other implementations](https://github.com/nektro/zig-time/blob/master/time.zig) are outdated and never accepted too.

[^1]: [Euclidean Affine Functions by Cassio and Neri.](https://arxiv.org/pdf/2102.06959)
