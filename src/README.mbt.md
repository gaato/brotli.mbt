# gaato/brotli

A streaming Brotli (RFC 7932) decoder in pure MoonBit. Native, JS, Wasm and Wasm GC.

```fish
moon add gaato/brotli
```

One shot:

```mbt check
///|
test "decompress a whole stream" {
  let compressed = b"\x0b\x02\x80hello\x03" // brotli.compress(b"hello")
  let text = @brotli.decompress(compressed, max_output=16 * 1024 * 1024)
  assert_eq(text, b"hello")
}
```

Streaming: feed input as it arrives, take output in slices of the size you choose.

```mbt check
///|
fn decode_all(chunks : Array[Bytes], sink : (BytesView) -> Unit) -> Unit raise {
  let decoder = @brotli.Decoder()
  let out = FixedArray::make(64 * 1024, b'\x00')
  for i, chunk in chunks {
    let mut input = chunk[:]
    for ;; {
      let status = decoder.step_into(input, out, end=i == chunks.length() - 1)
      input = input[decoder.last_consumed():]
      sink(Bytes::from_array(out[:decoder.last_produced()]))
      match status {
        Done => return
        NeedMoreInput => break
        NeedMoreOutput => ()
      }
    }
  }
}

///|
test "decode a stream chunk by chunk" {
  let decoded = Buffer()
  decode_all([b"\x0b\x02", b"\x80hel", b"lo\x03"], bytes => {
    decoded.write_bytes(bytes.to_owned())
  })
  assert_eq(decoded.to_bytes(), b"hello")
}
```

## What it does

- Decodes every RFC 7932 stream, including the static dictionary and its 121 transforms.
- Takes input in chunks of any size, down to one byte, and writes output into buffers of any size; the same `step` / `Status` shape as `moonbit-community/flate`.
- Memory is the window (at most 16 MiB, and no more than the output so far) plus tables of at most 1.3 MiB. `Decoder(max_window_bits=n)` refuses streams that need a window over `2^n` bytes.
- Every malformed stream raises `BrotliError(kind, message)`: `Truncated`, `Corrupt`, `TrailingData` (bytes after the stream), `WindowTooLarge` or `OutputLimitExceeded`. It does not abort.

Not included: an encoder, and the non-RFC large-window format.

## License

Apache-2.0. The static dictionary in `src/static_data.mbt` comes from [google/brotli](https://github.com/google/brotli) under the MIT license; see `LICENSE-dictionary`.
