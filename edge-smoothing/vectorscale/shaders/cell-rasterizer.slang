#version 450

// Cell rasterizer — renders optimized B-spline curves at viewport scale.
//
// For each output pixel, scans a 5x5 CP neighborhood, finds the nearest
// B-spline boundary via Newton-Raphson, resolves color from edge data,
// and applies analytical anti-aliasing at boundary edges.
//
// Multi-hit resolution: tries up to 4 nearest CPs with single-neighbor
// endpoint rejection, matching the compute shader's resolve_from_shared().
//
// Input textures:
//   Source   (FinalPositions): optimized absolute positions
//   CellGraph: original positions + neighbors + flags + packed directions
//   Original: input pixel art image
//
// Output: viewport-sized final image

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 CellGraphSize;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;    // FinalPositions (optimized positions)
layout(set = 0, binding = 3) uniform sampler2D CellGraph; // positions + neighbors + flags + directions
layout(set = 0, binding = 4) uniform sampler2D Original;  // input pixel art image

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_W() * CORNERS_H() * 2; }

// ---- Texture reading helpers ----

void decode_cp(int cp_idx, out int cx, out int cy_slot) {
    int cp_half = cp_idx / 2;
    int cp_slot = cp_idx & 1;
    int cx_ = cp_half % CORNERS_W();
    int cy_ = cp_half / CORNERS_W();
    cx = cx_;
    cy_slot = cy_ * 2 + cp_slot;
}

// Read original position from cell graph texture (row 0, RG channels).
vec2 read_orig(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(-1e10);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 val = texelFetch(CellGraph, ivec2(cx, base_row), 0);
    return vec2(val.r, val.g);
}

// Read optimized absolute position from Source.
vec2 read_pos(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(-1e10);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    vec4 val = texelFetch(Source, ivec2(cx, cy_slot), 0);
    return vec2(val.r, val.g);
}

// Decode a neighbor CP index from component encoding.
int decode_neighbor(vec4 val) {
    if (val.r < -0.5) return -1;
    int ncx = int(val.r + 0.5);
    int ncy = int(val.g + 0.5);
    int nslot = int(val.b + 0.5);
    return (ncy * CORNERS_W() + ncx) * 2 + nslot;
}

// Read neighbors from cell graph texture (row offsets 1 and 2).
ivec2 read_neighbors(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return ivec2(-1, -1);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 prev_val = texelFetch(CellGraph, ivec2(cx, base_row + 1), 0);
    vec4 next_val = texelFetch(CellGraph, ivec2(cx, base_row + 2), 0);
    return ivec2(decode_neighbor(prev_val), decode_neighbor(next_val));
}

// Read flags from cell graph texture (row 0, B channel).
uint read_flags(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return 0u;
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 val = texelFetch(CellGraph, ivec2(cx, base_row), 0);
    return uint(val.b + 0.5);
}

// Read packed boundary directions from cell graph (row 0, A channel).
// Returns (prev_dir, next_dir) where -1 = none, 0=N, 1=E, 2=S, 3=W.
ivec2 read_dirs(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return ivec2(-1, -1);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 val = texelFetch(CellGraph, ivec2(cx, base_row), 0);
    int dir_pack = int(val.a + 0.5);
    int prev_dir = (dir_pack % 8) - 1;
    int next_dir = (dir_pack / 8) - 1;
    return ivec2(prev_dir, next_dir);
}

// Get the grid corner (icx, icy) for a CP index.
ivec2 cp_grid_corner(int cp_idx) {
    int cp_half = cp_idx / 2;
    return ivec2(cp_half % CORNERS_W(), cp_half / CORNERS_W());
}

// Read pixel color from original image as normalized RGB.
vec3 read_pixel(int px, int py) {
    px = clamp(px, 0, IMG_W() - 1);
    py = clamp(py, 0, IMG_H() - 1);
    vec4 c = texelFetch(Original, ivec2(px, py), 0);
    return c.rgb;
}

// Compute edge colors for a boundary direction at grid corner (icx, icy).
void get_edge_colors(int icx, int icy, int dir, out vec3 color_left, out vec3 color_right) {
    switch (dir) {
        case 0: // N
            color_left  = read_pixel(icx - 1, icy - 1);
            color_right = read_pixel(icx,     icy - 1);
            break;
        case 1: // E
            color_left  = read_pixel(icx,     icy - 1);
            color_right = read_pixel(icx,     icy);
            break;
        case 2: // S
            color_left  = read_pixel(icx,     icy);
            color_right = read_pixel(icx - 1, icy);
            break;
        case 3: // W
            color_left  = read_pixel(icx - 1, icy);
            color_right = read_pixel(icx - 1, icy - 1);
            break;
        default:
            color_left = vec3(0.0); color_right = vec3(0.0);
            break;
    }
}

// ---- B-spline evaluation ----

vec2 beval(vec2 p0, vec2 p1, vec2 p2, float t) {
    float u = 1.0 - t;
    return 0.5 * u * u * p0 + (u * t + 0.5) * p1 + 0.5 * t * t * p2;
}

vec2 beval_deriv(vec2 p0, vec2 p1, vec2 p2, float t) {
    return (t - 1.0) * p0 + (1.0 - 2.0 * t) * p1 + t * p2;
}

// ---- Closest point on B-spline span ----

vec2 closest_on_span(vec2 p0, vec2 p1, vec2 p2, vec2 pt) {
    float best_d2 = 1e10;
    float best_t = 0.0;
    for (int s = 0; s <= 4; s++) {
        float t = float(s) * 0.25;
        vec2 bp = beval(p0, p1, p2, t);
        float d2 = dot(pt - bp, pt - bp);
        if (d2 < best_d2) { best_d2 = d2; best_t = t; }
    }

    vec2 b2 = p0 - 2.0 * p1 + p2;
    for (int i = 0; i < 4; i++) {
        vec2 bt = beval(p0, p1, p2, best_t);
        vec2 bt1 = beval_deriv(p0, p1, p2, best_t);
        vec2 diff = bt - pt;
        float f = dot(bt1, diff);
        float g = dot(b2, diff) + dot(bt1, bt1);
        if (abs(g) > 1e-10)
            best_t = clamp(best_t - f / g, 0.0, 1.0);
    }

    vec2 bp = beval(p0, p1, p2, best_t);
    best_d2 = dot(pt - bp, pt - bp);
    return vec2(best_t, best_d2);
}

// ---- Main rasterizer ----

void main() {
    ivec2 opos = ivec2(gl_FragCoord.xy);
    float out_w = params.OutputSize.x;
    float out_h = params.OutputSize.y;

    // Map output pixel to source coordinates.
    // This pass renders at a fixed source-relative resolution.
    // A passthrough pass after this handles viewport scaling via RetroArch's MVP.
    float scale_x = out_w / float(IMG_W());
    float scale_y = out_h / float(IMG_H());
    float scale = min(scale_x, scale_y);
    float inv_scale = 1.0 / scale;

    vec2 center = (vec2(opos) + 0.5) / vec2(out_w, out_h) * vec2(float(IMG_W()), float(IMG_H()));

    // Fallback: nearest pixel color (normalized RGB).
    int fb_x = clamp(int(floor(center.x)), 0, IMG_W() - 1);
    int fb_y = clamp(int(floor(center.y)), 0, IMG_H() - 1);
    vec3 fallback = read_pixel(fb_x, fb_y);

    // Determine which grid cell this output pixel is in.
    int cell_cx = int(floor(center.x));
    int cell_cy = int(floor(center.y));




    // Collect nearest boundary hits from CPs in a 5x5 neighborhood.
    struct Hit {
        float d2;
        float t;
        int cp_idx;
    };

    Hit hits[4];
    int num_hits = 0;
    for (int h = 0; h < 4; h++) { hits[h].d2 = 1e10; hits[h].cp_idx = -1; }

    // Scan CPs in neighborhood
    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
            int cx = cell_cx + dx;
            int cy = cell_cy + dy;
            if (cx < 0 || cy < 0 || cx >= CORNERS_W() || cy >= CORNERS_H()) continue;

            for (int slot = 0; slot < 2; slot++) {
                int ci = (cy * CORNERS_W() + cx) * 2 + slot;
                if (ci < 0 || ci >= NUM_CPS()) continue;

                uint flag = read_flags(ci);
                if (flag == 0u) continue;

                ivec2 nbrs = read_neighbors(ci);
                int prev_ci = nbrs.x;
                int next_ci = nbrs.y;
                if (prev_ci < 0 && next_ci < 0) continue;

                vec2 cp = read_pos(ci);
                vec2 pp = (prev_ci >= 0) ? read_pos(prev_ci) : cp;
                vec2 np = (next_ci >= 0) ? read_pos(next_ci) : cp;

                // Bounding box early out
                vec2 bb_min = min(min(pp, cp), np) - vec2(1.0);
                vec2 bb_max = max(max(pp, cp), np) + vec2(1.0);
                if (center.x < bb_min.x || center.x > bb_max.x ||
                    center.y < bb_min.y || center.y > bb_max.y)
                    continue;

                vec2 result = closest_on_span(pp, cp, np, center);
                float span_t = result.x;
                float span_d2 = result.y;

                if (span_d2 < 1.0) {
                    // Insert into sorted top-4 list
                    for (int h = 0; h < 4; h++) {
                        if (span_d2 < hits[h].d2) {
                            for (int j = 3; j > h; j--) hits[j] = hits[j-1];
                            hits[h].d2 = span_d2;
                            hits[h].t = span_t;
                            hits[h].cp_idx = ci;
                            if (num_hits < 4) num_hits++;
                            break;
                        }
                    }
                }

            }
        }
    }

    // Color resolution: try each hit (nearest first) until one resolves.
    // Matches compute shader's multi-hit fallback with single-neighbor rejection.
    vec3 center_color = fallback;
    bool resolved = false;

    for (int h = 0; h < num_hits && !resolved; h++) {
        int ci = hits[h].cp_idx;
        float hit_t = hits[h].t;
        float hit_d2 = hits[h].d2;

        ivec2 nbrs = read_neighbors(ci);
        int prev_ci = nbrs.x;
        int next_ci = nbrs.y;

        vec2 cp = read_pos(ci);
        vec2 pp = (prev_ci >= 0) ? read_pos(prev_ci) : cp;
        vec2 np = (next_ci >= 0) ? read_pos(next_ci) : cp;

        // Single-neighbor rejection: skip if pixel is on the wrong side of endpoint
        if (prev_ci < 0) {
            vec2 toward = np - cp;
            if (dot(center - cp, toward) < 0.0) continue;
        } else if (next_ci < 0) {
            vec2 toward = pp - cp;
            if (dot(center - cp, toward) < 0.0) continue;
        }

        // Compute edge colors on-the-fly from grid position + boundary direction
        ivec2 grid = cp_grid_corner(ci);
        ivec2 dirs = read_dirs(ci);
        int prev_dir = dirs.x;
        int next_dir = dirs.y;

        vec3 pl = vec3(0.0), pr = vec3(0.0), nl = vec3(0.0), nr = vec3(0.0);
        if (prev_dir >= 0) get_edge_colors(grid.x, grid.y, prev_dir, pl, pr);
        if (next_dir >= 0) get_edge_colors(grid.x, grid.y, next_dir, nl, nr);

        // Pick edge colors. Next edge SWAPPED (tangent at t=1 reverses normal).
        vec3 c_left, c_right;
        float ref_t;
        bool have_colors;
        bool prev_valid = any(notEqual(pl, pr));
        bool next_valid = any(notEqual(nl, nr));

        if (prev_ci < 0) {
            if (next_valid) { c_left = nr; c_right = nl; ref_t = 1.0; have_colors = true; }
            else continue;
        } else if (next_ci < 0) {
            if (prev_valid) { c_left = pl; c_right = pr; ref_t = 0.0; have_colors = true; }
            else continue;
        } else if (hit_t < 0.5) {
            if (prev_valid) { c_left = pl; c_right = pr; ref_t = 0.0; have_colors = true; }
            else if (next_valid) { c_left = nr; c_right = nl; ref_t = 1.0; have_colors = true; }
            else continue;
        } else {
            if (next_valid) { c_left = nr; c_right = nl; ref_t = 1.0; have_colors = true; }
            else if (prev_valid) { c_left = pl; c_right = pr; ref_t = 0.0; have_colors = true; }
            else continue;
        }

        // Original tangent for left/right convention
        vec2 orig_cp = read_orig(ci);
        vec2 orig_pp = (prev_ci >= 0) ? read_orig(prev_ci) : orig_cp;
        vec2 orig_np = (next_ci >= 0) ? read_orig(next_ci) : orig_cp;

        vec2 orig_tang = beval_deriv(orig_pp, orig_cp, orig_np, ref_t);
        float otl = length(orig_tang);
        if (otl < 1e-4) continue;
        vec2 orig_normal = vec2(-orig_tang.y, orig_tang.x) / otl;

        // Optimized curve tangent and signed distance
        vec2 opt_tang = beval_deriv(pp, cp, np, hit_t);
        float opt_tl = length(opt_tang);
        if (opt_tl < 1e-4) continue;
        vec2 opt_normal = vec2(-opt_tang.y, opt_tang.x) / opt_tl;

        vec2 curve_pt = beval(pp, cp, np, hit_t);
        float d = dot(center - curve_pt, opt_normal);

        // Determine left/right using original normal orientation
        bool flip = dot(opt_normal, orig_normal) < 0.0;
        vec3 pos_side = flip ? c_right : c_left;
        vec3 neg_side = flip ? c_left : c_right;

        // AA threshold: boundary within pixel diagonal
        float aa_threshold = 2.0 / (scale * scale);
        if (hit_d2 < aa_threshold && any(notEqual(pos_side, neg_side))) {
            float pw = inv_scale;
            float proj_w = pw * (abs(opt_normal.x) + abs(opt_normal.y));
            float frac = clamp(0.5 + d / proj_w, 0.0, 1.0);
            center_color = frac * pos_side + (1.0 - frac) * neg_side;
        } else {
            center_color = (d > 0.0) ? pos_side : neg_side;
        }
        resolved = true;
    }

    FragColor = vec4(center_color, 1.0);
}
