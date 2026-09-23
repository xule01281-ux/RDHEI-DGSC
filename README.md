# RDHEI-DGSC reference implementation

Complete MATLAB main-chain implementation of **Reversible Data Hiding in Encrypted Images via Dynamic Gravity Prediction Axes and Spatial Collaborative Error Correction**. This local v1.1.0 package includes DGP-Axes, SCEC, segmented rANS encoding and decoding, auxiliary-information codecs, AES-CTR encryption, embedding, extraction and image recovery.

The public demo executes the complete algorithm and checks every recovered pixel and payload bit. Capacity-only and timing experiments have separate entry points. There is no external binary or withheld rANS module.

## Requirements

- MATLAB R2023a (tested on Windows 64-bit).
- Image Processing Toolbox (`padarray`) and Statistics and Machine Learning Toolbox (`tabulate`).
- MATLAB JVM enabled for AES-CTR. Windows uses .NET for cryptographic random key/IV generation.
- 8-bit grayscale input. Image dimensions must be divisible by the square block size (8, 16, 32 or 64; default 16). No automatic resizing or colour conversion.

Only Windows R2023a has been validated for this release. Other platforms are not claimed as tested.

## Run the complete demonstration

Unzip the package, set the MATLAB current folder to its root, then run:

```matlab
rdhei_setup
main
```

The default input is a freely redistributable 256-by-256 synthetic image. Results appear in `results/generated/synthetic`: original, encrypted carrier, final marked image, recovered image, a MAT result file and JSON metrics. Secret credentials are not written by this demo.

For a supplied image:

```matlab
main(fullfile('data','11.png'))
[summary,images,detail] = rdhei_case(imread(fullfile('data','11.png')));
assert(summary.image_pixel_mismatches == 0)
assert(isequal(detail.embedded,detail.extracted))
```

`detail.crypto` contains the randomly generated secret credentials in memory. The old numeric key arguments in `Encrypt_Embed` are compatibility placeholders; they are not AES keys.

The receiver's existing element, block and full-image assertions are retained. Some function arguments supply sender reference arrays for these assertions. This release provides a reproducible complete experiment; it does not claim a redesigned standalone receiver API or a new separate-process validation.

## Reproduce measurements

Place the exact Man (`11.png`), Jetplane, Baboon and Tiffany inputs in `data`, or pass their directory. File and decoded-pixel hashes are listed in `results/reference/input_manifest.json`.

```matlab
test_full_release                         % synthetic, constant, short-payload, codec and fixed-vector tests
test_full_release('your_image_folder')    % additionally tests the four natural images
run_capacity_suite('your_image_folder')   % 8,16,32,64 blocks; stop at exact net capacity
run_scec_ablation('your_image_folder')    % seven SCEC groups, fixed DGP split
run_dgp_comparison('your_image_folder')  % current SCEC, DGP / centre / peak / row-column axes
benchmark_forward('your_image_folder',3) % one warm-up per image, then sequential repeats
run_damage_suite('your_image_folder',fullfile('results','generated','damage.json'),'full')
```

Run timing in an otherwise idle MATLAB session without parallel experiments. `forward_seconds` starts immediately before prediction and ends after auxiliary protection and final block/pixel scrambling. It excludes image I/O, random payload/key generation and receiver work. The full call still validates recovery after that interval.

Net ECC is the number of actual secret bits divided by original pixel count. It accounts for rANS states, block/global headers, folded residual positions, skipped-block arrangements, prediction references and displaced bytes. The external 53-byte public header is reported separately. A short-payload experiment reports actual embedded length as well as maximum capacity; encrypted padding is not counted as secret payload.

`run_capacity_suite` computes actual headers and the exact writable-slot count without encryption, payload writing, scrambling or image recovery. Its count is cross-checked against complete embedding in the release tests. Console estimates inside older core functions are diagnostic only; use the returned summary or JSON fields.

## Large datasets and split runs

The dataset scripts do not start until explicitly called. They support resume, per-image errors, source snapshots, extrema and original image IDs. No BOSSBase/BOWS2 full dataset is included or run during release preparation.

```matlab
run_dataset_ecc_part(1,'both','BossPath','your_BOSSBase_folder','BowsPath','your_BOWS2_folder')
run_dataset_ecc_part(2,'both','BossPath','your_BOSSBase_folder','BowsPath','your_BOWS2_folder')
merge_dataset_ecc
```

Each part processes 5000 images per dataset. Defaults save to `results/dataset_part1`, `results/dataset_part2` and `results/dataset_merged`. Use explicit `StartIndex`, `EndIndex` and `OutputRoot` with `run_dataset_ecc` for other partitions. Merging rejects overlapping/missing indices and incompatible code/configuration. See `docs/datasets.md`.

## Source map

| Task | Implementation |
|---|---|
| Public demo / full experiment | `main.m`, `rdhei_case.m` |
| Complete production flow | `src/Encrypt_Embed.m` |
| Initial prediction / DGP / SCEC | `src/Copy_of_Predictor_Value2.m`, `deviate.m`, `med_4dir_prediction.m` |
| Block arrangement / segmented rANS encoding | `src/select_block.m`, `Copy_of_complete_bit.m` |
| Block/global serialization | `src/block_in_support.m`, `block_in_support2.m` |
| Payload writing / encryption | `src/Embed_Data_Encrypt_Data.m`, `Encrypt_Data.m`, `aesCtrImageEncrypt.m` |
| Payload extraction / rANS and image recovery | `src/Extract_Data2.m`, `Recover_Image2.m` |
| Residual-to-image reconstruction | `src/recover_from_prediction_error.m`, `prediction_reference_codec.m` |
| Public layout / recovery-field protection | `src/read_global_support.m`, `packet_bit_layout.m`, `protect_recovery_fields.m` |
| Dataset capacity / resume / merge | `src/dataset_capacity_tests/` |

Legacy filenames containing `Copy_of_` are retained where they are the functions actually called by the current implementation. Historical unused `rANS_encode.m` variants are not the active encoder and are not shipped.

## Format and implementation notes

See `docs/bitstream.md` for field order, widths, placement and reference codec pointers, and `docs/implementation.md` for prediction parameters and preserved implementation behavior. `examples/synthetic_vector.mat` contains a deterministic, public test vector; its fixed credentials are solely test data and must not be used with real images.

The release preserves numerical prediction and encoding behavior except for a documented Huffman edge-case repair: a one-symbol alphabet now receives code `0`, and an unused segment-length alphabet is serialized with a dummy symbol. Production project files outside this package were not changed. See `docs/source_manifest.json` and `docs/changes.md`.

AES-256-CTR provides no authentication in this prototype. The scrambling seed is public; scrambling is not a confidentiality mechanism. The public header exposes payload length. Recovery tests concern intact inputs; failures under damage are not authentication guarantees. Exact reconstruction requires intact image data and the necessary public parameters and credentials.

## License and publication

Source is supplied under the MIT License; see `LICENSE`. The synthetic test input is generated by this package. Standard images and external datasets are not redistributed. No code from the S+PEE repository is included.

This archive was prepared locally for the authors to upload. A public repository URL and final citation should be added after publication of the repository. The complete rANS implementation is included in this release; the earlier predictor-only release plan is superseded.


## Paper experiment archive / 论文实验档案

See [docs/paper_experiments.md](docs/paper_experiments.md) for the manuscript table index, exact protocols, preserved raw records and portable commands. The main-chain code is unchanged from v1.0.0. Reference records are separate from newly generated results.
