# Input images

No third-party images or datasets are redistributed. The no-argument `main` generates its own 256-by-256 synthetic grayscale input.

The four natural-image experiments expect `11.png` (Man), `Jetplane.tiff`, `Baboon.tiff` and `Tiffany.tiff`, each 512-by-512 uint8 grayscale. Obtain these inputs from your authorized source and compare the file/pixel SHA-256 values in `results/reference/input_manifest.json` before comparing exact capacities.

Default dataset folders are `data/BOSSBase` and `data/BOWS2`, containing their original PGM images. Alternatively pass `BossPath` and `BowsPath`. Dataset licenses and usage conditions remain those of their providers.
