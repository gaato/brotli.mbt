# Changelog

All notable changes to `gaato/brotli` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). While the version is
0.x, a minor release (0.x → 0.y) may contain breaking changes; a patch release
never does. Every breaking change is listed with a migration note.

## [Unreleased]

### Added

- `Decoder`, a streaming RFC 7932 decoder: `step` (into a `MutArrayView`) and
  `step_into` (into a `FixedArray`) take input in chunks of any size and
  write output into buffers of any size, answering `Status` (`Done`,
  `NeedMoreInput`, `NeedMoreOutput`); `end=true` marks the last input.
  `last_consumed`, `last_produced`, `is_finished` and `reset`.
- `max_window_bits` on `Decoder` and `decompress` (24 by default): streams
  needing a larger window raise `WindowTooLarge`.
- `decompress`, a one-shot decoder with an optional `max_output`.
- `BrotliError(BrotliErrorKind, String)` for every malformed stream:
  `Truncated`, `Corrupt`, `TrailingData`, `WindowTooLarge` and
  `OutputLimitExceeded`.
