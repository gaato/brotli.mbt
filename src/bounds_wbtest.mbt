///|
/// The largest distance alphabet: NDIRECT 120, NPOSTFIX 3.
const MAX_DISTANCE_ALPHABET : Int32 = 16 + 120 + (48 << 3)

///|
/// Checks the limits RESOURCE_BOUNDS.md states, after a step that had
/// `room` bytes of output.
fn check_bounds(d : Decoder, room : Int32) -> Unit raise {
  // Output slices.
  assert_true(d.last_produced() <= room)
  // The unfinished unit: at most 63 bits of input.
  assert_true(d.stash.length() - d.stash_pos <= 8)
  // The window.
  assert_true(d.ring_max <= 1 << d.max_window_bits)
  assert_true(d.ring.length() <= d.ring_max)
  assert_true(d.pending <= d.ring.length())
  // Prefix code tables: in this meta-block, then over the stream.
  let (lit, cmd, dist) = (d.lit_trees, d.cmd_trees, d.dist_trees)
  assert_true(lit.used <= d.lit_trees_count * max_table_size(NUM_LITERALS))
  assert_true(cmd.used <= d.num_types[1] * max_table_size(MAX_ALPHABET))
  assert_true(
    dist.used <=
    d.dist_trees_count * max_table_size(16 + d.ndirect + (48 << d.npostfix)),
  )
  assert_true(lit.pool.length() <= 256 * max_table_size(NUM_LITERALS))
  assert_true(cmd.pool.length() <= 256 * max_table_size(MAX_ALPHABET))
  assert_true(dist.pool.length() <= 256 * max_table_size(MAX_DISTANCE_ALPHABET))
  for c in 0..<3 {
    assert_true(d.type_codes[c].pool.length() <= max_table_size(258))
    assert_true(
      d.count_codes[c].pool.length() <= max_table_size(NUM_BLOCK_COUNT_CODES),
    )
  }
  assert_true(d.map_code.pool.length() <= max_table_size(256 + 16))
  assert_true(d.code.cl_code.pool.length() <= max_table_size(18))
}

///|
test "output slices, the stash and the tables stay within their bounds" {
  for v in vectors {
    guard v.size <= 300000 else { continue }
    let got = drive(
      Decoder(),
      v.input(),
      next_in=() => 1,
      next_out=() => 997,
      check=check_bounds,
    )
    assert_eq(@checksum.sha256(got), v.sha256, msg=v.name)
  }
}

///|
test "the window is at most 1 << WBITS and grows only with output" {
  let window = (name : String) => {
    let v = vectors[vectors.search_by(v => v.name == name).unwrap()]
    let decoder = Decoder()
    let mut largest = 0
    let got = drive(
      decoder,
      v.input(),
      next_in=() => 4096,
      next_out=() => 65536,
      check=(d, room) => {
        check_bounds(d, room)
        largest = largest.max(d.ring.length())
      },
    )
    assert_eq(got.length(), v.size)
    (largest, decoder.ring_max)
  }
  // A one-byte stream with a 4 MiB window allocates the first 1 KiB only.
  debug_inspect(window("x.compressed"), content="(1024, 4194304)")
  // A 1 KiB window wraps instead of growing.
  debug_inspect(window("gen/window10"), content="(1024, 1024)")
  // 5 MiB of output under a 16 MiB window: the window stops at 8 MiB.
  debug_inspect(
    window("gen/window24_far"),
    content=(
      #|(8388608, 16777216)
    ),
  )
}
