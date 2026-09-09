# VectorScale

VectorScale is a GPU implementation of the "Depixelizing Pixel Art" algorithm
by Johannes Kopf and Dani Lischinski (SIGGRAPH 2011). Instead of interpolating
pixels, it traces the image into a network of smooth quadratic B-spline curves
every frame and rasterizes those curves directly at the output resolution. The
result is resolution-independent: edges stay sharp and curves stay smooth at
any scale factor, integer or not.

It is a port of the vectorizer from [vibeboy](https://github.com/northbymidwest/vibeboy),
restructured as a chain of fragment-shader passes that communicate through
floating-point framebuffers.

# Presets

| Preset | Optimizer | Anti-aliasing | Notes |
|---|---|---|---|
| `vectorscale.slangp` | simple | single + multi curve | Recommended default |
| `vectorscale-single-aa.slangp` | simple | single curve | Cheaper; skips the multi-curve refinement pass |
| `vectorscale-exact-energy.slangp` | exact | single + multi curve | Closer to the paper, slower |
| `vectorscale-exact-energy-single-aa.slangp` | exact | single curve | |

**Simple** uses the L2 curvature approximation `|p[i-1] - 2 p[i] + p[i+1]|^2`
with a Newton solver. **Exact** minimizes the paper's turning-angle energy
(theta squared over two, the discrete form of the integral of |kappa| ds)
using alternating per-point Newton steps and a global gradient correction.

> [!WARNING]
> The exact-energy presets are experimental and currently produce artifacts on
> some inputs. Under certain configurations the optimizer moves control points
> far enough that neighboring curves cross over each other. That changes the
> topology of the vectorization, and in the regions between the crossed curves
> the correct color is no longer well defined. The original fast (simple)
> optimizer is less prone to this and is the recommended choice.

Both optimizers add the paper's positional energy, `(2.5 * distance)^4`, which
keeps control points near their original grid positions.

# Pipeline

Each preset runs the same front and back end. Only the optimizer passes in the
middle differ.

1. **similarity-graph** builds the pixel connectivity graph at 2x resolution
   and records an 8-way valence mask per pixel.
2. **resolve-crossings** breaks ambiguous diagonal crossings using the paper's
   three heuristics: curve length, sparse pixels, and islands.
3. **cell-graph** places B-spline control points at grid corners and links
   them into chains. It classifies corners, T-junctions, crossings, and
   endpoints, and snaps isolated single pixels so they keep their full size.
4. **bake-neighbor-endpoints** caches per-point endpoint bits for the
   rasterizer.
5. **init-positions** seeds the optimizer with the original positions.
6. **optimize-energy-simple** or **optimize-energy** plus
   **gradient-correction** relax the control points against curvature and
   positional energy.
7. **update-tjunction** snaps each T-junction stem onto its through curve.
8. **pack-positions** writes the final per-point curve geometry the
   rasterizer consumes, including curve-curve intersections at crossings.
9. **active-cell-mask** stores per source pixel which control points can
   render inside it, so solid interior pixels skip the rasterizer entirely.
10. **cell-rasterizer-single-aa** finds the nearest curve to each output
    pixel, picks the colors on either side, and applies exact tangent-line
    coverage anti-aliasing in linear light.
11. **cell-rasterizer-multi-aa** refines only the pixels where a second
    curve is close: wedge coverage where two curves meet inside the pixel,
    and dual-curve coverage for thin strokes.

# References

Johannes Kopf and Dani Lischinski. "Depixelizing Pixel Art." ACM
Transactions on Graphics (Proceedings of SIGGRAPH 2011), 30(4).

# License

Zero-Clause BSD. See [LICENSE](LICENSE).
