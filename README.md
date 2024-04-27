# datetime

![zig-version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fclickingbuttons%2Fdatetime%2Fmaster%2F.github%2Fworkflows%2Ftest.yml&query=%24.jobs.test.steps%5B1%5D.with.version&label=zig-version)
![tests](https://github.com/clickingbuttons/datetime/actions/workflows/test.yml/badge.svg)
[![docs](https://github.com/clickingbuttons/datetime/actions/workflows/publish_docs.yml/badge.svg)](https://clickingbuttons.github.io/datetime)

Generic Date, Time, and DateTime library.

Features:
- Convert to/from epoch subseconds using world's fastest known algorithm. [^1]
    - Specify your own epoch.
- Choose your own year and subsecond types.
- Durations.
- [ ] Timezones
- [ ] RFC3339
- [ ] Localization
- [ ] Leap seconds

## Why yet another date time library?
- There are uses for different precisions for years, subseconds, and UTC offsets.
- There are uses for different epochs.

[^1]: Epoch conversion implemented using [Euclidean Affine Functions by Cassio and Neri.](https://arxiv.org/pdf/2102.06959)
