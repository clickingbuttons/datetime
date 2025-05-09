# datetime

![zig-version](https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Fclickingbuttons%2Fdatetime%2Frefs%2Fheads%2Fmaster%2Fbuild.zig.zon&search=minimum_zig_version%5Cs*%3D%5Cs*%22(.*)%22&replace=%241&label=minimum%20zig%20version)
![tests](https://github.com/clickingbuttons/datetime/actions/workflows/test.yml/badge.svg)
[![docs](https://github.com/clickingbuttons/datetime/actions/workflows/publish_docs.yml/badge.svg)](https://clickingbuttons.github.io/datetime)

Generic Date, Time, and DateTime library.

## Installation
```sh
zig fetch --save "https://github.com/clickingbuttons/datetime/archive/refs/tags/0.14.0.tar.gz"
```

`build.zig`
```zig
const datetime = b.dependency("datetime", .{
    .target = target,
    .optimize = optimize,
});
your_lib_or_exe.root_module.addImport("datetime", datetime.module("datetime"));
```

Run `zig build` and then copy the expected hash into `build.zig.zon`.

## Usage

Check out [the demos](./demos.zig). Here's a simple one:
```zig
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
    - Timezone offset.

In-scope, PRs welcome:
- [ ] Localization
- [ ] Leap seconds

## Why yet another date time library?
- I frequently use different precisions for years, subseconds, and UTC offsets.
- Systems use different epochs and Zig aims to be a sytems language.

[^1]: [Euclidean Affine Functions by Cassio and Neri.](https://arxiv.org/pdf/2102.06959)
