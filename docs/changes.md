# Release changes

Version 1.0.0 packages the active implementation frozen on 20 September 2026.

1. Added portable demo, full-case wrapper, capacity/time/ablation experiment entries and tests. Original production files outside the package remain unchanged.
2. Added optional output 8 (`recover_I`) to the packaged `Encrypt_Embed` to expose the image it already reconstructs and verifies. Its numerical body is unchanged.
3. Repaired a pre-existing one-symbol Huffman failure. `buildHuffmanTree` preserves the root's symbol when it is a leaf; `generateCodes` assigns that leaf code `0`. Multi-symbol tree construction and ordering remain unchanged.
4. If all inter-segment zero-length lists are empty, `block_in_support` serializes a dummy symbol 0 for the unused length table. This table is not consulted by blocks with at most one segment. The actual extra header bits are counted normally.
5. Replaced machine-specific dataset and output defaults with package-relative defaults. The half-dataset wrapper forwards optional path arguments. Capacity arithmetic and journaling/merge logic are unchanged.
6. Reused the existing SCEC ablation and damage-test kernels in their own directories, with portable public runners. The damage decoder adds timeout checks around the production logic; original assertions remain enabled.
7. Added `AsArray=true` to per-image CSV conversion so a one-image partition or first checkpoint exports a single table row correctly. This fixes output handling only; no capacity value is changed.

Source/release hashes and the per-file changes are recorded in `source_manifest.json`. Reference results describe this package. They must not be combined with old parameter configurations under an identical version label.


## Version 1.1.0 paper archive

Added paper-matched Table 3/4/5/7/8/10/11/12 entries, immutable formal raw records, exact source IDs/splits, fixed ciphertext baseline inputs, and numerical table regeneration. Table 8 now has a dedicated ten-candidate finite-search entry; Table 11 has the exact two-warm-up/ten-repeat protocol and rotating order. Historical v1.0.0 quick checks remain explicitly separate. Every src file is byte-identical to v1.0.0. No full dataset or full formal experiment was rerun for packaging. A limited entry-validation record is provided. The archive is still local until the author uploads it.
