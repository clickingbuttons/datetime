# datetime

![zig-version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fclickingbuttons%2Fdatetime%2Fmaster%2F.github%2Fworkflows%2Ftest.yml&query=%24.jobs.test.steps%5B1%5D.with.version&label=zig-version)
![tests](https://github.com/clickingbuttons/datetime/actions/workflows/test.yml/badge.svg)
[![docs](https://github.com/clickingbuttons/datetime/actions/workflows/publish_docs.yml/badge.svg)](https://clickingbuttons.github.io/datetime)

Generic Date, Time, and DateTime library.

## Installation
`build.zig.zon`
```zig
.{
    .name = "yourProject",
    .version = "0.0.1",

    .dependencies = .{
        .@"datetime" = .{
            .url = "https://github.com/clickingbuttons/datetime/archive/refs/tags/latest-release.tar.gz",
        },
    },
}
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
    - Specify your own epoch.
- Choose your own year and subsecond types.
- Durations.
- Timezones
- RFC3339
- [ ] Localization
- [ ] Leap seconds

## Why yet another date time library?
- I frequently use different precisions for years, subseconds, and UTC offsets.
- Systems use different epochs and Zig aims to be a sytems language.

[^1]: [Euclidean Affine Functions by Cassio and Neri.](https://arxiv.org/pdf/2102.06959)
