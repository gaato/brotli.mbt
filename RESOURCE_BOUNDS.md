# Resource bounds

What a decoder holds, and what keeps each structure from growing without
limit. The rule: **every structure that grows with the input is listed here
with its bound**. A new one needs a row before it ships.

**Every row of "Enforced limits" names a test that checks the bound**, in its
Tests column: a backticked file path, then the quoted names of that file's
tests. A test counts only if it drives the structure to its limit, or checks
the bound after every step over streams that push it. `scripts/bounds_check.sh`,
run by `scripts/gates.sh`, enforces the naming; whether a named test really
reaches the bound is checked in review. The other tables are prose.

## Enforced limits

| Structure | Bound | On overflow | Tests |
|---|---|---|---|
| Sliding window (`src/decoder.mbt`, `ring`) | At most `1 << WBITS` bytes, so at most 16 MiB (WBITS 24); allocated from 1 KiB, doubling only as output needs it. A stream declaring a window over `1 << max_window_bits` (24 by default, clamped to 10..24) is refused before anything is allocated; large-window (non-RFC) streams are refused | `WindowTooLarge`; `Corrupt` for large-window streams | `src/bounds_wbtest.mbt`: "the window is at most 1 << WBITS and grows only with output", "output slices, the stash and the tables stay within their bounds"; `src/decode_wbtest.mbt`: "max_window_bits refuses larger windows and is clamped"; `src/crafted_wbtest.mbt`: "malformed streams raise the error the RFC calls for" |
| Output slice (`Decoder::step`, `Decoder::step_into`) | At most the caller's buffer per step, down to 1 byte; the rest waits in the window | `NeedMoreOutput` | `src/bounds_wbtest.mbt`: "output slices, the stash and the tables stay within their bounds"; `src/decode_wbtest.mbt`: "any fixed input split and output size give the same output" |
| Unfinished unit (`src/decoder.mbt`, `stash`) | 8 bytes: the longest unit, a command, is 63 bits. Every other input byte is decoded or reported unconsumed | Cannot overflow: a unit that has its bytes completes | `src/bounds_wbtest.mbt`: "output slices, the stash and the tables stay within their bounds"; `src/fuzz_wbtest.mbt`: "corrupted streams raise errors or decode, within bounds, never abort" |
| Prefix code tables (`src/huffman.mbt`, `Group`) | Per tree, alphabet + 376 entries of 2 bytes (the reference decoder's bound). Per meta-block at most 256 literal trees (632 entries each), 256 insert-and-copy trees (1,080) and 256 distance trees (896 at most): 1.3 MiB in the worst case, allocated for the trees a meta-block declares and kept for the next | Cannot overflow: RFC 7932 caps tree counts and alphabets | `src/bounds_wbtest.mbt`: "output slices, the stash and the tables stay within their bounds"; `src/fuzz_wbtest.mbt`: "corrupted streams raise errors or decode, within bounds, never abort" |
| One-shot output (`decompress`, `max_output`) | `max_output` bytes when given; unlimited by default | `OutputLimitExceeded` | `src/decode_wbtest.mbt`: "decompress honours max_output" |

## Fixed per decoder

| Structure | Size |
|---|---|
| Context maps | 16 KiB (literals) + 1 KiB (distances) |
| Code length scratch, table builder scratch, block type state | About 8 KiB |
| Transformed dictionary word | 37 bytes |
| The static dictionary and transform tables | 122,784 + about 1 KiB, shared by all decoders |

## Left to the caller

| Structure | Grows with | Why it is not bounded here |
|---|---|---|
| Total output of a stream | The stream | `step` hands it out in slices; the caller decides what to keep |
| Input chunks | What the caller passes | `step` keeps no reference to them after it returns |
| `decompress` output | The stream | It returns the whole output; pass `max_output`, or use `Decoder` |
