ArtCNN is a neural network based image doubler aimed at anime content. This port is based on the [ArtCNN shader sources](https://github.com/Artoriuz/ArtCNN/) for use with the emulator front-end RetroArch.

# Usage

Place the files in a folder in RetroArch\shaders\shaders_slang\. Make sure you are using the Vulkan renderer in the RetroArch config.

This port only includes the real-time GLSL luma models:
* C4F16
* C4F16 DN
* C4F16 DS
* C4F32
* C4F32 DN
* C4F32 DS

The example presets upscale luma with ArtCNN, upscale chroma with Jinc2, and merge back to RGB. They finish with another Jinc2 pass for viewport scaling. You can replace Jinc2 with whatever other viewport scaler you want.

# Filenames

What various suffixes in the filenames mean:

* -luma: Triggered on the luma channel only.
* -2x: The amount of upscaling being done.
* -c4f16: The lighter and faster model.
* -c4f32: The heavier and slower model, but usually the better-looking one.
* -dn: A version trained to reduce noise and look a bit softer.
* -ds: A version trained to reduce noise but still look sharper.

For example:
* "artcnn-c4f16-2x-luma.slangp": Scale luma 2x with the lighter C4F16 model. Chroma is scaled with Jinc2.
* "artcnn-c4f32-dn-2x-luma.slangp": Scale luma 2x with the heavier C4F32 DN model, which tries to smooth noise a bit more.
* "artcnn-c4f32-ds-2x-luma.slangp": Scale luma 2x with the heavier C4F32 DS model, which tries to keep a sharper look.

# Notes

* The original ArtCNN shaders are compute-based mpv GLSL shaders.
* This port serializes those stages into fragment-only slang passes because RetroArch slang shaders are fragment based.
* ArtCNN also has larger offline-only models, chroma models, and JPEG cleanup models. Those are not part of this port.
* The ArtCNN MIT notice is included in "LICENSE".
