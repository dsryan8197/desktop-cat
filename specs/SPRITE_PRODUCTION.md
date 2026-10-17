# Sprite artwork production requirements

## Two approved art directions
1. `fluffy_b`: thick dark pixel outline, rounded fluffy silhouette, limited warm shading, expressive face, pale chest and tail. Reference: `references/selected_fluffy_B.png` (the B panel at top right).
2. `orange_c`: stronger chunky outline, fewer pixels, flat orange/cream color fields, tiny minimalist face. Reference: `references/selected_chunky_C.png` (orange C1 cat).

## Export specifications
- Draw at a consistent base resolution per cat (suggest 48x48 or 64x64 for fluffy_b; 32x32 or 48x48 for orange_c, depending on actual silhouette); larger actions can use wider canvas but keep anchor point consistent.
- Transparent RGBA PNG, no backdrop, labels, tile frames, shadows, or decorative UI baked into sprites.
- Pixel-perfect nearest-neighbor rendering. No automatic bilinear interpolation.
- Consistent feet baseline/pivot for ground poses; separate anchor metadata for window, airborne and dragged poses.
- Filename format exactly matches `specs/cats-and-actions.json`, in each cat's asset folder.
- Each individual PNG frame must show ONLY ONE pose and be safely cropped/padded into a fixed-size cell. For each action check that frames depict actual consecutive movement rather than duplicates.
- Horizontal mirroring can be used for facing left if anatomically appropriate; do not mirror asymmetrical markings if it changes the intended design.
- The supplied image-generation concept sheets are references, NOT dependable sprite sheets: slicing them would preserve text, backdrops, inconsistent poses, and unwanted artifacts.

## Quality checks
- Compare outline weight, colors, head-to-body proportion, ear shape, markings and eye placement across all frames.
- Check motion in an animated preview at 100%, 200%, 300% scale.
- Confirm transparent background, stable anchor point, no shimmering/jitter, no clipping of tail and paws.
- Do not mark action READY until its frames exist and preview correctly.

## Art backlog
All action IDs and target frame filenames are in `specs/cats-and-actions.json`. Start with:
`idle_sit`, `blink`, `walk`, `turn`, `stretch`, `lie_down`, `sleep`, `wake_up`, `jump_prep`, `jump`, `land`, `peek`, `groom`, `happy`, `carried`, `nap_window`.

## Color variants
Colorways can be added AFTER both base cats animate well. Prefer a palette swap pipeline with per-cat masks rather than manually making all actions multiple times.
