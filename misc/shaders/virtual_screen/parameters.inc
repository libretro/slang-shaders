// See the main shader file for copyright and other information.

// clang-format off
#pragma parameter VIRT_SCREEN_SETTINGS "=== Virtual Screen v1.0 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter VIRT_SCREEN_ASPECT_H "Horizontal aspect ratio (0 = unchanged)" 0.0 0.0 256.0 1.0
#pragma parameter VIRT_SCREEN_ASPECT_V "Vertical aspect ratio (0 = unchanged)" 0.0 0.0 256.0 1.0
#pragma parameter VIRT_SCREEN_SHAPE "Screen shape (0 = sphere, 1 = cylinder)" 0.0 0.0 1.0 1.0
#pragma parameter VIRT_SCREEN_CURVATURE "Curvature strength" 0.5 0.0 1.5 0.05
#pragma parameter VIRT_SCREEN_ZOOM "Zoom" 0.99 0.8 1.2 0.01
#pragma parameter VIRT_SCREEN_TILT_ANGLE "Vertical tilt" 0.0 -0.5 0.5 0.01
#pragma parameter VIRT_SCREEN_F "Focal Length (max = ortho)" 2.0 0.5 10.0 0.25
#pragma parameter VIRT_SCREEN_ROUNDED_CORNER "Rounded corner radius" 0.02 0.0 0.2 0.01
// clang-format on
