CuNNy (Convolutional upscaling Neural Network, yeah!) is a small, fast neural-network image doubler trained for visual novels, game artwork, and high-quality illustrations. This RetroArch slang port is based on the [CuNNy Magpie shader sources](https://github.com/funnyplanter/CuNNy) and includes models from the NVL family.

# Usage

Keep this directory at `RetroArch\shaders\shaders_slang\edge-smoothing\cunny\` so the presets can find RetroArch's interpolation shaders, and use a video driver that supports slang shaders. Vulkan is the recommended one to use.

Every included preset performs 2x neural-network upscaling and finishes with a Jinc2 pass for scaling the result to the viewport. You can replace that final pass with another viewport scaler if you prefer.

The presets fall into two groups:

* Luma: `veryfast`, `faster`, and `fast`. These run the network on luminance while scaling chroma quickly with bilinear. They are the lightest and fastest options.
* RGB: `3x12`, `4x12`, `4x16`, `4x24`, `4x32`, and `8x32`. These run the network on all three color channels and provide higher quality at a greater GPU cost.

The intended quality order is:

`8x32` > `4x32` > `4x24` > `4x16` > `4x12` > `3x12` > `fast` > `faster` > `veryfast`

Speed generally follows the reverse order. `fast` is a good starting point for slower hardware. Larger models can recover more complex detail, although the best-looking choice can still depend on the game and display resolution.

# Filenames

What the parts of the preset filenames mean:

* `veryfast`, `faster`, and `fast`: progressively heavier luma models.
* `3x12`, `4x12`, `4x16`, `4x24`, `4x32`, and `8x32`: network depth x feature width. Higher numbers are generally better. For example, `4x32` has four internal convolution stages with 32 feature channels, while `8x32` doubles the internal depth but keeps the same width.
* `nvl`: the model was trained for visual novels and high-quality illustrations.
* `2x`: the neural network doubles the source dimensions. The first number in `4x32` or `8x32` is not an upscale factor.
* `luma`: the network processes luminance. The processed luminance is recombined with the bilinearly scaled chroma for RGB output.
* `rgb`: the network processes all three color channels.

For example:

* `CuNNy-veryfast-nvl-2x-luma.slangp`: the lightest luma model for slower hardware.
* `CuNNy-3x12-nvl-2x-rgb.slangp`: the smallest RGB model with three internal stages and 12 feature channels.
* `CuNNy-4x32-nvl-2x-rgb.slangp`: a heavier RGB model with four internal stages and 32 feature channels.
* `CuNNy-8x32-nvl-2x-rgb.slangp`: the deepest and highest-quality included RGB model, with eight internal stages and 32 feature channels.

# Notes

* The original CuNNy NVL shaders are Magpie effects built around multi-render-target stages.
* This port serializes the network into RetroArch-compatible fragment shader passes.
* Intermediate feature groups are stored as full-image atlas tiles. This reduces the required pass count while preserving the network.
* Only the NVL models listed above are included. Other versions of CuNNy haven't been ported since they weren't specifically trained for use on games.
* The Magpie shaders this port is based on are licensed under GPL-3.0-or-later, and this port is distributed under the same license.
