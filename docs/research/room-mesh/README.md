# Room mesh viewing and trimming

September 11, 2026

The room viewer needs two explicit camera modes: an outside orbit to understand the overall capture, and an inside viewpoint to inspect the enclosed room. Double-sided materials alone do not solve a camera that always stays outside the walls and ceiling.

For an accidentally captured hallway, the recommended first editing tool is a **top-down rectangular selection with Remove / Keep, a preview, and a reversible save**. The recommendation is a product judgment based on the workflows below. An orthographic floor plan makes the room/hallway boundary easier to place than a selection drawn over an oblique 3D view.

## Reference patterns

| Primary source | Established interaction | Application here |
| --- | --- | --- |
| [Polycam: Crop a Capture](https://learn.poly.cam/hc/en-us/articles/29647360522516-How-to-Crop-a-Capture-in-Polycam) | Bounding-box handles, inside/outside inversion, Apply, Undo/reset. Mesh cropping is distinct from floor-plan editing. | Drag a rectangle or move corners; clearly shade what will be removed; preview before saving. |
| [CloudCompare: Interactive Segmentation](https://cloudcompare.org/doc/wiki/index.php/Interactive_Segmentation_Tool) | Screen-space rectangle/polygon, keep inside/outside, adjust, validate or cancel. Its mesh segmentation removes crossing triangles. | Use the same selection vocabulary, but clip crossing triangles to the boundary so coarse scan triangles do not leave avoidable gaps. |
| [Apple: PerspectiveCameraComponent](https://developer.apple.com/documentation/realitykit/perspectivecameracomponent) | A non-AR camera has an explicit position, orientation, clipping distance and field of view. | Inside mode rotates at a fixed position; zoom changes field of view rather than moving the camera back outside. |

A freehand brush is a poor first tool for a full-height hallway: screen-space selection can unintentionally catch surfaces behind the intended target, and erasing every wall/ceiling fragment is tedious. Polygon selection is a useful later extension for irregular room boundaries. A rotatable crop box and height-limited cuts are also useful extensions; this implementation deliberately presents a full-height rectangle and explains that scope in the editor.

## Implemented flow

1. Open a room in Mesh and switch **Outside / Inside**. Inside mode offers look-around, zoom and an expandable floor-plan position control with accessible coordinate steppers.
2. Choose **Trim room** below the mesh or in Room actions.
3. Draw or resize a top-down rectangle. **Remove selection** removes the hallway through the scan's full height; **Keep selection** crops to the room instead. The shaded region is always the portion to remove. Edge steppers provide an alternative to dragging.
4. **Preview trim** builds the actual clipped mesh for inspection in either camera mode. **Adjust selection**, **Undo selection**, Reset and Cancel permit revision before saving.
5. **Save revision** writes a new immutable room revision and opens it. Reopening and exports use the saved trimmed mesh. The original is still accessible in Revisions.

## Geometry and evidence semantics

- Triangles are clipped in room coordinates, including transformed AR mesh patches. Classifications follow each resulting face; unused vertices are compacted. Cut surfaces remain open: no invented caps, walls or filled holes.
- Room and coordinate-frame IDs remain stable, the edited revision references its parent, and the original file is unchanged.
- Recognized components crossing the selection are omitted conservatively. Floor-area and volume estimates disappear when their complete floor is no longer retained. The original semantic payload is not exported as though it described the edited geometry.
- Dimensions crossing a removed area are omitted from the edited revision. Separate saved readings and their coordinates remain untouched; the editor and revision note explain this.
- The orientation map remains attached because trimming does not change the coordinate frame. It is used for relocalization, not as the exported surface model.
- Empty, invalid and no-op trims are rejected before saving. A save failure leaves the preview available to retry.

## Verification

Evidence and current test results are recorded in [validation.md](validation.md). The supplied screenshot is visual context only; it does not contain the user's original mesh payload. Simulator fixtures establish camera and editing behavior, not acceptance against that exact physical scan.
