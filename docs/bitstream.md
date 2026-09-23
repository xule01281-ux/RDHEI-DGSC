# Bitstream and placement specification

This document describes the current protected auxiliary format, protocol version 2. Source files named below are normative for traversal, tie resolution and arithmetic. No opaque implementation is needed: all writers and readers are supplied. The MAT demonstration container is an experiment artifact, not an additional communication-format requirement.

## 1 Representation and public parameters

All integer fields are unsigned, MSB first, unless stated otherwise. Image dimensions come from the received pixel array. Blocks and block-header lists are ordered by block row then column. Pixels within a block are serialized by row then column. A pixel byte is visited MSB to LSB. `image_bits.m` addresses a bit as `8*(MATLAB_linear_pixel_index-1)+bit`, where bit=1 is the MSB.

Default blocks are 16-by-16. The final block/interior permutation uses public seed 123, `RandStream('mt19937ar')`, first `randperm(number_of_blocks)`, then `randperm(h*w)`. Blocks are collected in MATLAB column-major cell order; pixels inside each block are also column-major for this permutation. See `scramble_blocks_within.m` and its inverse. Block size and this permutation convention must be known before unscrambling; block size is checked again in the decoded header.

An external **53-byte** public header accompanies the image:

| Bytes (1-based) | Field |
|---|---|
| 1 | Protocol version, value 2 |
| 2–17 | Image AES-CTR IV |
| 18–33 | Payload AES-CTR IV |
| 34–49 | Recovery-field AES-CTR IV |
| 50–53 | Actual secret payload length, uint32 big endian |

Three independent 32-byte keys are generated. Image and auxiliary keys form the image recovery credential; the data key controls payload decryption. Keys are not in this public header. AES uses `AES/CTR/NoPadding`; full byte arrays and bit-stream padding follow `aesCtrImageEncrypt.m`, `aesCtrImageDecrypt.m` and `aes_ctr_bits.m`. Fresh contexts are generated for ordinary calls. Fixed keys in `examples/synthetic_vector.mat` are public test credentials only.

## 2 Physical order

The encoder predicts, folds residuals, selects block arrangements and encoded prefixes, creates rANS states and block/global auxiliary fields, encrypts the transformed carrier, then writes block headers and displaced bytes/payload. Selected recovery fields are protected with the auxiliary AES stream, followed by final scrambling.

Each active block places its header first, followed by writable positions through byte `opt`. Global auxiliary bytes overwrite positions `(H,W),(H,W-1),...`, then row `H-h`, then `H-2h`, etc. The final partial byte is zero padded. These positions are excluded from payload slots. Prefix bytes displaced by this overwrite are saved first in the remaining slots; encrypted payload follows. Unused secret capacity is encrypted zero padding. The public header determines the true secret length.

For L global bits, `covered=ceil(L/8)` and `saved=min(floor(L/8)+1,ceil(covered/W)*W)`. The saved-byte rule preserves the historical writer's extra look-ahead byte on an exact byte boundary away from a row end. Displaced length is `8*saved`, not always `8*ceil(L/8)`. `global_aux_layout.m`, `packet_bit_layout.m` and `dataset_capacity_only.m` implement this layout and capacity accounting.

Auxiliary protection XORs fields enumerated by `packet_bit_layout`: global frequency values; the reference area after the public opt method header; block arrangement bits and rANS state bits (excluding physical global overlap); displaced-byte slots. Length and navigation fields remain public so the protected positions can be located. Payload positions have their own independent AES stream. The receiver unscrambles, extracts/decrypts the payload, reverses auxiliary protection, restores displaced bytes and decodes image symbols.

## 3 Global auxiliary field order

Let N=H*W, B=(H/h)*(W/w), `q=ceil(log2(h*w/8+1))`. These fields are emitted by `block_in_support2.m` and read by `read_global_support.m`:

| Field | Width / interpretation |
|---|---|
| h, w | `ceil(log2(H+1))`, `ceil(log2(W+1))` bits |
| Any skipped blocks | 1 bit; 0 means all blocks active |
| Skipped-block map, if present | method bit: 0 then B row-major bitmap bits; 1 then `count-1` and that many zero-based positions, each `ceil(log2(B))` bits |
| max_l | 4 bits in supported configurations |
| Zero-frequency width | `floor(log2(floor(log2(N+1))+1))+1` bits |
| Frequency for byte 0 | Number of bits specified above |
| Other-frequency width | Same width-of-width field |
| Frequencies for bytes 1..255 | 255 fixed-width counts, including zeros |
| Huffman table for ns | Format below |
| Huffman table for l_d_best | Format below |
| Huffman table for l_0 | Format below |
| Reference-section length | 14 bits, maximum 16383 |
| Reference section | Exactly the declared number of bits |

Each Huffman table is `K(q) | code_lengths(K*q) | value_width(q) | concatenated_codes | K_values`. Values are sorted unique symbols; each value uses `value_width` bits. The codes are sent explicitly; a receiver need not reproduce Huffman tie ordering. A one-symbol table uses code `0`. An unused l_0 table contains dummy symbol 0.

The frequency counts sum to N before auxiliary protection. While decoding blocks in reverse raster order, the receiver subtracts the recovered current block's symbol counts before processing the preceding block. It does not use original sender symbols for this update.

## 4 Reference section

The current order is:

```text
opt method header | 11 | folded-residual map | skipped-block arrangements | prediction references
```

`opt` method 00 uses `ceil(log2(h*w))` bits for `opt-1` in each active block; method 01 adds a 4-bit Rice k to the global method header. In method 01 each block header stores a Paeth-predicted opt residual using Rice coding. Neighbor defaults are 1. Signed residual d maps to `2*abs(d)-(d<0)`. Rice uses q zero bits, one terminator and k remainder bits. The encoder falls back to fixed-width if total cost or individual block fit is unfavorable. See `opt_header_codec.m`, `encode_opt_headers.m`, `read_opt_headers.m`.

`11` is the extension containing both fold map and skipped-block arrangements. A fold map of N row-major pixels uses 00 for all-zero, 01 all-one, 10 plus N raw bits, or 11 plus minority value (1 bit), minority count (`ceil(log2(N+1))`), k (`max(1,ceil(log2(ceil(log2(N))+1)))`) and Rice-coded position gaps. Gaps equal current one-based position minus previous position minus one; previous initially 0. See `fold_map_codec.m`.

Skipped blocks reuse their known positions. Zero skipped blocks have no arrangement bits; one has `r-1` in 2 bits. Multiple blocks choose 0 plus two bits each, or 1 plus two independently compressed arrangement bit planes using the fold-map codec. See `skipped_r_codec.m`.

Prediction reference mode 01 is constant-image mode, followed by one 8-bit gray anchor. Mode 00 contains zero-based split row/column (`ceil(log2(H))`, `ceil(log2(W))`), four 2-bit directions, 2-bit spatial pattern, statistics and anchor values. Direction codes 0..3 mean TL/TR/BL/BR, in geometric region order TL/TR/BL/BR.

Each statistics group transmits four exact integer gradient numerators with widths `ceil(log2(255*sample_count+1))`, then sigma as a 64-bit IEEE-754 pattern, MSB first. Counts are Hregion*(Wregion-1), (Hregion-1)*Wregion, and (Hregion-1)*(Wregion-1) for both diagonals. Regions smaller than 4096 pixels share one full-image group. Reference positions/order are derived by `prediction_reference_layout.m` and `expand_prediction_references.m`. Anchor values use a one-bit raw/compressed flag: raw has 8 bits each; compressed adds 3-bit Rice k, first value in 8 bits, then Rice-coded signed successive differences. The number of anchors is inferred from geometry. `prediction_reference_codec.m` is the complete symmetric serializer.

## 5 Active block header

```text
opt code | r-1 (2 bits) | b0 | Huffman(ns) | segment fields
```

`b0=0` has no more fields. `b0=10` is followed by `log2(w)` bits for a leading special zero run minus one. `b0=11` uses `log2(w)+max_l` bits. See the first-nonzero/run handling in `Copy_of_complete_bit.m` and the symmetric parser in `Recover_Image2.m`.

- ns=0: no segment fields.
- ns=1: final state width (6 bits), one frequency-table mode bit, then the state in the declared width.
- ns>1: final state width (6), Huffman(l_d_best), ns-1 Huffman(l_0) values, ns-1 state-width flags, ns frequency-table mode bits, final segment state, then states for segments 1..ns-1. A width flag 1 uses l_d_best bits; flag 0 uses 53 bits. The final state's width is independent.

Each block's actual header length must be at most 8*opt. Non-fitting blocks are marked skipped and contribute no payload slots. Their selected arrangement is transmitted in the global reference section.

## 6 rANS state and reversal

`select_block.m` tries the four arrangements; `Copy_of_complete_bit.m` produces the chosen encoded prefix and per-segment states/modes. States remain below 2^53 to preserve exact double-integer arithmetic. Initial state 0 seeds directly from the ordered symbol rank. Otherwise, for frequency f, cumulative c and total M, the forward state is `floor(x/f)*M + rem(x,f) + c`, plus M when x<M. The proposed state reaching 2^53 closes the prior segment. Frequency scaling, alternate-table construction, special zero runs, truncation scoring and segment ordering are provided in that source rather than hidden behind a compiled library.

`Recover_Image2.m` builds both matching tables from decoded counts, reads every segment mode/state, and uses integer arithmetic for inverse state updates. It handles the seeded state and +M branch explicitly. It restores every block's symbols before decrementing global frequencies, checks each symbol/block against the supplied test references, reverses arrangement via `reverse_block_processing.m`, then performs inverse signed/fold mapping and prediction reconstruction.

## 7 Limits and test vectors

The reference section has a 14-bit length limit. A header that exceeds it raises an error; it is not silently truncated. Capacity-only runs report failures separately if auxiliary storage cannot fit. Full round-trip validation covers the supplied synthetic vector, constant and short-payload cases, and four identified natural inputs; this is not proof that every possible image is encodable.

The fixed public vector contains exact original/stego pixel arrays, payload, external header and explicitly public AES test keys/IVs. `test_full_release` regenerates and compares them byte-for-byte. Codec tests cover raw/sparse maps, opt coding, malformed/truncated fields and the one-symbol Huffman case.
