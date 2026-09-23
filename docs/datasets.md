# Capacity-only dataset runs

`run_dataset_ecc` runs prediction, residual folding, block selection, actual rANS state/header construction and exact physical slot accounting. It does not encrypt, write payload, scramble, extract or reconstruct. A completed capacity record therefore does not claim a recovery test.

```matlab
rdhei_setup
run_dataset_ecc('both','BossPath','your_BOSSBase_folder','BowsPath','your_BOWS2_folder')
run_dataset_ecc_part(1,'both','BossPath','your_BOSSBase_folder','BowsPath','your_BOWS2_folder')
run_dataset_ecc_part(2,'both','BossPath','your_BOSSBase_folder','BowsPath','your_BOWS2_folder')
merge_dataset_ecc
```

Choose either a complete run or the two-part run with separate result roots. Do not run both against one output directory. Each part processes 5000 images from each dataset, according to the numerically sorted filenames. Image IDs are the actual filenames without extensions, not the local loop counter.

Custom ranges and small trials:

```matlab
run_dataset_ecc('BOSSBase','BossPath','your_BOSSBase_folder', ...
 'StartIndex',1,'EndIndex',20,'OutputRoot',fullfile('results','dataset_trial'))
```

The input check requires 512-by-512 uint8 grayscale PGM. No automatic conversion is applied. Each first run stores a source snapshot and manifest. Subsequent calls to the same output root resume from JSONL records. Configurations and files must remain unchanged. Set `RetryFailed`,true to retry recorded failures.

Per-image output includes net bits, ECC, source SHA-256, auxiliary costs, errors and elapsed capacity time. Summaries separately report each dataset's maximum/minimum bit counts and ECC, retaining every tied image ID. Failed cases remain failures and are not averaged as zero. The complete-dataset mean is left empty until every image has succeeded.

To stop gracefully, create an empty `STOP` file inside the result root. The current image finishes and progress is saved. Remove the file before resuming. Do not delete `.running_lock` while its process is active; after a crash, confirm the process has ended before removing the stale empty lock directory.

Merging reads records without encoding images. It checks coverage, duplicate indices, source/configuration compatibility and completion. Source parts cannot still be running. The merged output must differ from input roots. Full BOSSBase/BOWS2 statistics are not supplied with this release; the scripts are provided for reproducible execution.
