# Implementation conventions

## Prediction

The signed prediction residual is `E=P-I`, in [-255,255]. Initial prediction starts at the top-left and uses fixed first-row/column references. DGP computes a rounded squared-error centroid, constrained to rows 2..H-1 and columns 2..W-1. The vicinity radius is 0.25 times the smaller image dimension; energy fraction >0.40 selects pattern 1, <0.10 pattern 2, otherwise pattern 0.

Regions are ordered top-left, top-right, bottom-left, bottom-right. Each compares directions TL,TR,BL,BR in that order, retaining the first on ties. Default selection uses the empirical bit-plane-byte entropy proxy, not trial full-system encoding. SSE remains an explicit comparator. Region statistics use the whole image when the region has fewer than 4096 pixels.

Regional local gradients are capped at 80; the initial predictor does not apply that cap. The gradient exponent is 2, local gradient offset 0.1, diagonal distance factor sqrt(2). Feedback weight is clamped to [0.4,0.6]; bias bound is `max(0.4*sigma,abs(xh-xv)/4)` and neighborhood margin is `max(0.4*sigma,10)`. Predictions use MATLAB rounding and final [0,255] clipping. Extreme-value replacement is disabled.

Pattern 0 applies feedback throughout the regional interior. Pattern 1 applies it within the vicinity, pattern 2 outside. Statistical and spatial conditions are retained exactly in `med_4dir_prediction.m`; changing a condition requires new capacity and reconstruction checks.

The current TR/BL implementation swaps its two diagonal gradients inside the pixel traversal, including boundary visits, so their assignment alternates. This release preserves that behavior in both prediction and recovery, and in the matching ablation kernel. It does not silently change it to a once-per-direction swap. Source consistency is not a claim that this implementation detail is theoretically optimal.

## Residual representation

Fold `e>128` to `e-128`, and `e<-127` to `e+128`; retain an explicit per-pixel flag for either operation. Other values remain unchanged. Folded `u` is in [-127,128]. Map to one byte by `2*u-1` if positive, otherwise `-2*u`, yielding [0,255]. For inversion, odd mapped values give `(v+1)/2`, even values `-v/2`. A flagged positive folded value adds 128, a flagged nonpositive value subtracts 128. In particular, e=-128 folds to zero with flag 1, whereas e=0 has flag 0.

After rANS symbol recovery, inverse block arrangement restores mapped pixels, inverse signed mapping and fold flags restore E, and the predictor regenerates P sequentially to reconstruct `I=P-E`. Prediction anchor pixels, directions, exact gradients and sigma are serialized; they are included in net capacity.

## Experiment scope

`run_scec_ablation` fixes the DGP split obtained from the full configuration, retains the same initial error map, and reselects directions for each group using the same entropy proxy. The seven groups remove all SCEC, feedback, spatial scheduling, bias clamp or neighborhood clamp, or fix feedback weight to 0.5. The full group is checked against production residuals and prediction reference bits. No extreme-intervention group is included.

`run_dgp_comparison` compares the squared-error centroid with a geometric midpoint, maximum squared-error pixel and separate maximum row/column error sums. Each axis pair uses current SCEC and identical capacity accounting. These are finite heuristic candidates, not a global optimum search.

Damage tests preserve the public 53-byte header and keys. They attack the final marked pixels. A recovery attempt stops on production assertions or a 30-second decoding guard. A failed/incomplete reconstruction does not receive an invented PSNR. Fresh random keys mean ciphertext bytes and the exact effect of a selected attack can vary across runs. Fixed synthetic vectors separately cover bit-exact reproducibility.

The experiment set supplies main-chain reproduction, capacity/block-size tests, SCEC/DGP comparisons, timing and damaged-input evaluation. The release does not claim that the two complete 10,000-image dataset runs have been performed. External baseline implementations and paper typesetting files are outside this main-chain package.


## Paper-matched archive

For the manuscript tables use experiments/paper and docs/paper_experiments.md. The original run_dgp_comparison and benchmark_forward entries are release checks, not the Table 8 and Table 11 protocols. Current paper records are under results/paper; results/reference preserves the earlier release-validation scope. Additional independent baseline capacity kernels and their measurement limitations are now supplied in experiments/paper/baselines. Full BOSS/BOWS capacity runs remain pending.
