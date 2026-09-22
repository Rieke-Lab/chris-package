# chris-package
Collections of Rieke Lab symphony protocols

## Natural-image contrast scaling

`edu.washington.riekelab.chris.protocols.LinearEquivalentDiscConeLinContrastScalor`
ports Turner's `LinearEquivalentDiscConeLin` using the new Chris base
`NatImgFlashWithContrastScalor`. Existing protocols and base classes are unchanged.
Images and the patch library load from this package's `+resources` directory.

Set `contrastScalor = 1` for the original stimulus, or enter a matrix such as
`[1 0.5 0]`. Every entry must be finite and between 0 and 1. Each entry scales
all pixels about the original whole-image mean:

```matlab
contrastImage = contrastScalor * (imageMatrix - imageMean) / imageMean;
scaledImage = imageMean + imageMean * contrastImage;
```

The whole-image mean and presentation background stay fixed; individual patch
means move toward the whole-image mean. Zero gives a uniform image. The original
8-bit conversion is retained, so display quantization can produce a small mean
rounding error. At 1, the original pixels and equivalent-disc calculations are
retained exactly. Both standard and cone-linearized equivalent discs are computed
from the scaled contrast before display quantization.

Each patch receives an `image`, `intensity` pair, or an `image`, `intensity`,
`linConeIntensity` triplet when `linearizeCones = true`, at every scalar before
advancing to the next patch. Matrices are traversed in MATLAB column-major order.
The original seeded patch selection is shared across scalars, including ranked
and biased sampling; patch-library rankings are not recalculated after scaling.
`numberOfAverages` still counts total epochs. One full cycle requires
`noPatches * numel(contrastScalor) * (2 + double(linearizeCones))` epochs.

Every epoch saves `currentContrastScalor` and `contrastScalorIndex` alongside the
patch, stimulus tag, and both equivalent intensities. Mean traces group by
stimulus tag and scalar. `ImageVsIntensityContrastScalorFigure` pairs responses
only within the same patch and scalar, with a separate color for each scalar.

Numerical regression tests (MATLAB, from the repository root):

```matlab
addpath(pwd);
results = runtests('tests/testNaturalImageContrastScalor.m');
assertSuccess(results);
```

These check all 20 bundled images, identity and zero scaling, mean preservation,
contrast reduction, invalid scalar rejection, and pair/triplet sequencing.
Symphony/Stage presentation and acquisition still require validation on the rig.
