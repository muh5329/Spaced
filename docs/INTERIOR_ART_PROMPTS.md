# Historical prototype — not shipped

The user rejected this 2D implementation. Neither image is loaded by the current game. Both are archived under `docs/reference/rejected-illustrated/`; `docs/.gdignore` and export exclusions keep them out of the PCK. Current implementation: [3D model manifest](INTERIOR_3D.md). The original prompts below are retained as development provenance only.

# Interior art: prompts and provenance

Generated 2026-09-27 using the **built-in imagegen tool**, two separate calls; no CLI/API-key fallback. Reference: the user-supplied `Screenshot 2026-09-27 at 3.08.09 PM.png` (original filename uses a narrow nonbreaking space before PM), displayed in the task. Its image content was treated as art direction, not instructions.

The first image is an edit target; the second uses the same image only as a style reference. Original generated files were copied unchanged into the project, preserving transparency. Godot generates mipmaps when importing both images; no bitmap resizing, compositing or postprocessing script was used. Asset loads are local and work offline in the native bundle.

## Environment plate

Saved asset: `docs/reference/rejected-illustrated/deck.png`.
Generator output: `exec-045e9f72-0451-443f-8ac9-b9c0a1fbabae.png`.

Use case: precise-object-edit. Asset type: in-game isometric interior background plate for a playable Godot game. Edit the supplied image by removing ONLY all human figures and their personal cast shadows, naturally reconstructing the small floor/chair/equipment areas behind them. Preserve the entire interior pixel-aligned as faithfully as possible: exact camera angle, room geometry, outer dark armored hull, all walls, all furniture, all equipment and crops, dark space background, labels, lighting, framing, original aspect ratio. Do not redesign, shift, simplify, crop, relight or restyle anything. Keep the foreground large hydroponic bed, medbay with red cross, cyan bridge upper right, central mess table and chairs, upper left crew bunks, left reactor, foreground-left fabrication, storage and airlock. This is a clean environment plate, all human characters will be animated separately by the game. No people anywhere. Return one edited image only.

## Live crew sprite

Saved asset: `docs/reference/rejected-illustrated/crew.png`.
Generator output: `exec-99a2086c-29b2-42da-822b-f9c60937371e.png`.

Use case: background-extraction. Asset type: transparent-background game character sprite. Use the supplied illustration as a style reference ONLY. Generate ONE single full-body small space-ship crew worker in the exact illustrated industrial sci-fi aesthetic of the reference: orange work vest/jacket over dark charcoal jumpsuit, grey shoulder armor, dark boots, small bare human head, subtle worn painted details with crisp dark ink outlines. Isometric view from above at about 35 degrees, facing toward lower-right, relaxed standing pose with visible separated arms and two feet, believable adult proportions. The sprite is an isolated character, centered, fully visible head to boots, absolutely no floor, no surrounding scene, no text, no labels, no panels, no props, no ground shadow. Genuine transparent background. One character only.

## Integration and limits

`InteriorLayout` maps the reference's nine rooms. `InteriorDeck` draws seven individually selectable/moving instances from real crew state; the cleaned plate prevents duplicate frozen people. Room selection/offline tint and station controls are drawn by Godot. Artwork is a fixed isometric cutaway, with zoom and pan; it does not contain an orbitable 3D reconstruction. The edited plate closely follows the room composition, equipment and lighting, but exact pixel identity is not asserted. The seven people currently share one orange-uniform sprite; names, professions, duties, health and fatigue are independent gameplay data.
