# Saved-room capture and revision specification

September 10, 2026. Proposed native implementation contract, accompanying [instrument visualization research](INSTRUMENT_CAPTURE_RESEARCH.md). No physical scan, merge implementation, or accuracy certification is represented by this document.

## Product behavior

A room is a named, saved measurement space. It can contain several capture revisions and saved measurements. Opening a room never requires beginning a new scan. Updating adds a new revision after review; it cannot destroy the last successful capture.

The default saved-room view should show its mesh, capture date, revision, and prominent **Update room** action. **Mesh**, **Plan**, and **Measurements** are coordinated views of the selected revision. Selecting a wall or dimension should retain the selection between views. A revision menu opens history and comparison.

The intended journey is **New room → Scan → Review → Save room → Reopen → Update room → Align → Capture another pass → Review → Save new revision**. At every acquisition or processing failure, the user retains a path to their saved room.

## Preserve three different kinds of data

| Data | Purpose | What it does not establish |
| --- | --- | --- |
| Detailed ARKit surface mesh | Inspect observed surfaces, keep original geometric evidence, perform appropriate spatial queries | Complete unseen geometry, semantic correctness, or automatic changed-object reconciliation |
| RoomPlan CapturedRoom/structure | Recognized walls, openings, objects, dimensions, and simplified plan/model | A lossless dense LiDAR recording or all physical surface detail |
| ARWorldMap plus reference image | Attempt to recover the earlier spatial coordinate system on a later visit | An always-successful resume operation or a complete standalone mesh archive |

ARMeshAnchor partitions and refines reconstructed surface geometry. Apple notes that mesh updates are not intended to reflect real-world object changes in real time. Persist our own versioned geometry buffers and transforms instead of depending on live anchors to remain identical across sessions. [ARMeshAnchor](https://developer.apple.com/documentation/arkit/armeshanchor).

Apple's world-map sample saves spatial data and a reference image, then attempts relocalization. Tracking can remain in the relocalizing state indefinitely if the environment does not match sufficiently; the product therefore needs an explicit recovery route. [Saving and loading world data](https://developer.apple.com/documentation/arkit/saving-and-loading-world-data), [initialWorldMap](https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration/initialworldmap).

RoomPlan's USD export options include parametric, mesh, and model-replacement representations. Its mesh export is a representation of the recognized room, not a substitute for retaining all independently captured surface data. Treat USDZ as a convenient view/share artifact. Keep native room data and measurement metadata separately. [USD export options](https://developer.apple.com/documentation/roomplan/capturedroom/usdexportoptions).

## Capture screen and review

**Preparation.** Check LiDAR/scene-reconstruction support, RoomPlan support, camera permission, local storage, and current tracking capability. Keep viewing saved data available on devices that cannot capture. Explain storage or hardware limitations at the action that depends on them. Ask for camera access only when starting capture.

**Acquisition.** Show the camera as the dominant surface, a restrained observed-mesh overlay, a compact plan/coverage view, and one coaching instruction. A capture status is factual: tracking available, tracking limited, or capture paused. Progress represents observations, not a fabricated whole-room completion percentage. Recording continues only with a clearly defined session state.

**Finishing.** A Finish control moves into processing and review. Keep the last valid snapshot available while derived representations build. Use named processing stages without simulated progress. If model extraction fails but the dense mesh was saved, allow the user to retain and inspect that usable partial capture with its limitation stated.

**Review.** Offer orbit, pan, zoom, fit room, reset view, plan, section/cutaway, and component selection. Geometry hidden for viewing remains part of the retained capture. The first screen should make missing coverage visible. A measurement list supplies a non-spatial navigation route.

**Saving.** The user names the room and optionally adds a note. Save local data before reporting success. A room thumbnail, capture time, and revision number provide a stable return point. Optional cloud transfer has its own status after local completion.

## Later visits and alignment

| State | Visible behavior | Exit/recovery |
| --- | --- | --- |
| Saved room | Previous mesh and revision remain inspectable | Update room or continue inspection |
| Ready to update | Reference photo and brief advice to start near the previous viewpoint | Start camera or cancel |
| Locating room | Show live camera and reference cue; keep old geometry out of the live world until alignment is valid | Successful relocalization, retry from reference, or save a separate capture |
| Aligned | Confirm alignment with outline, text, and optional haptic; enable the next capture step | Begin pass or cancel |
| Capturing pass | Differentiate previous surfaces from current observations; expose pause/finish | Finish or handle tracking loss |
| Tracking lost | Stop accepting data into the old coordinate frame; preserve the partial pass | Recover alignment or finish as a separate segment/revision |
| Reviewing | Linked-camera previous/current views, coverage legend, measurements, alignment status | Save new revision, resume compatible capture, or discard draft |
| Saved | New revision selected, previous revision still available | Compare, measure, export, or another update |

Relocalization should provide progressively useful guidance and a retry/separate-capture choice. A prototype can start with a roughly 15-second coaching threshold, but that is a usability hypothesis, not an API deadline or accuracy rule. The user can keep trying. Never use elapsed time as evidence that alignment succeeded.

When alignment fails, a new scan may remain a child revision of the same named room while carrying a distinct coordinate-frame identifier and **Not spatially aligned** status. Show it separately. Spatial change overlays and coordinate-dependent deltas stay unavailable until a validated alignment exists. Saving this capture is useful work even when precise comparison is unavailable.

## What “update the mesh” means

Separate these operations in the model and product:

1. **Add a pass.** Save another observed mesh and its provenance.
2. **Align passes.** Establish their coordinate relationship with recorded evidence.
3. **Review differences.** Show what was observed in each pass, without conflating missing observations with physical removal.
4. **Reconcile surfaces.** If implemented and validated, produce a derived latest mesh while retaining the source passes.

The first three can deliver a useful room-update workflow before a robust general fusion algorithm exists. The fourth is required before promising that an old chair disappears correctly from one consolidated room mesh after a later scan.

RoomPlan's StructureBuilder accepts rooms in compatible world coordinates. A continuous ARSession or successful map restoration supplies that spatial continuity. It does not document arbitrary dense-mesh boolean union, object change detection, or guaranteed cross-session anchor identity. [StructureBuilder](https://developer.apple.com/documentation/roomplan/structurebuilder/capturedstructure(from:)).

**Recommended initial behavior:** retain each aligned pass as immutable source geometry; allow prior/current comparison; offer a latest-pass view. An accumulated coverage view can include surfaces from multiple passes only with last-observed provenance and an unmistakable legend. Do not label that view a fully current room unless reconciliation has been validated.

**Coverage legend:** blue for observations in this pass, muted prior geometry for older observations, hatch for not observed this time. Reserve a distinct selection outline for the user's chosen component. “Different between captures” is a candidate difference until alignment and repeated measurement support a stronger interpretation. An area outside the camera view is unknown, not removed.

**Comparison:** provide a before/after slider or side-by-side view with linked cameras and fixed scale. Show capture dates and alignment status continuously. Dimensions compare only when endpoints/components can be meaningfully matched. Report the measurement method and avoid implying that reconstruction variation is necessarily a physical change.

## Proposed local data contract

Use one room identifier with immutable revision identifiers. Distinguish observation time from save time. Store physical coordinates in meters, with explicit coordinate-frame identifiers and transforms. Display units are a preference, not a rewrite of the measurement geometry.

```text
Room
  id, name, createdAt, selectedRevisionID
  revisions[]

Revision
  id, roomID, parentRevisionID, schemaVersion
  captureStartedAt, captureEndedAt, savedAt
  deviceCapabilities, OS/app version, captureConfiguration
  coordinateFrameID, alignmentStatus, parentFromRevisionTransform?
  alignmentEvidence?, trackingEvents[], warnings[]
  surfaceMeshAssets[]       vertices, faces, normals, classes?, transforms
  semanticRoomAsset?        native encoded CapturedRoom/structure data
  worldMapAsset?            resumable alignment aid
  relocalizationImage?      reference view with capture metadata
  depthEvidenceAssets[]?    selected frames/patches with confidence and calibration
  observations[]           source pass, time, observed extent/provenance
  measurements[]           endpoints/patches, method, value, unit, quality evidence
  derivedAssets[]          display simplification, preview, USDZ; source IDs/version
  assetManifest            byte counts, checksums, schema, required/optional flags
```

This is a proposed schema, not an Apple serialization contract. Copy mesh buffers before asynchronous processing so retained data does not depend on later live-session mutation. Keep original and simplified display meshes distinct. Depth assets are optional and bounded; saving every camera/depth frame by default would impose an unvalidated storage burden.

A stored world map may be unavailable or unsuitable for later use. Capability flags should therefore describe what the local bundle can actually do: **view**, **measure**, **attempt alignment**, and **capture new pass**. An imported USDZ may support viewing while lacking native provenance or reliable scale for measurements. Do not infer editability or resumability from its file extension.

**Write integrity.** Write a draft revision into a temporary location, verify required assets, commit its manifest, then publish it in the room index atomically where supported. On restart, recover a verified draft or offer to discard an incomplete draft; never replace the last saved revision with partial data. This transaction scheme requires implementation and fault-injection validation.

**Deletion and retention.** Deleting a display/export cache can be reversible through regeneration. Removing original observations or the reference map changes future capabilities, so show the exact effect in storage management. A user-requested revision deletion should not cascade to unrelated revisions. Restore means select or derive from an older revision, preserving history.

**Optional cloud.** Follow the product's explicit opt-in behavior on each installation. Preserve local operation and distinguish locally saved from uploaded. Concurrent edits create sibling revisions rather than overwriting one another. Viewing a downloaded room and resuming a scan on a different device are separate capabilities; cross-device capture continuation remains a physical validation item.

**Exports.** Provide a lightweight viewable USDZ, a measurement report with units/method/revision, and a native editable bundle if import/export is implemented. Name any omitted source/alignment assets. Exporting a visually attractive model must not be represented as a complete archival backup.

## Measurement and rendering rules

Distance measurements persist their actual endpoints and owning revision. A mesh-local face reference may help selection, but it cannot be the only identity because reconstructed topology can change. Plane measurements record the sampled region and whether plane flattening/smoothing affected the source.

Keep four quality dimensions distinct: tracking/alignment, observed coverage, depth confidence, and measurement repeatability. None alone establishes absolute accuracy. A single 98% quality badge would hide these differences and requires a separately validated definition before use.

The mesh viewer should use neutral materials and modest directional lighting that reveal surface shape. Depth mode requires a numeric legend and explicit invalid regions. Semantic classifications may tint selected components, but recognized furniture geometry must remain visibly an estimate. Avoid photorealistic furniture replacement in the measurement view because it can imply detail that was never observed.

For floor plans, compute a closed outline before exposing area. Preserve holes and multiple regions. For volume, record whether the result uses a simple height extrusion or a closed 3D surface. If the chosen method cannot represent a sloped or incomplete ceiling, report incomplete/unsupported geometry rather than a precise-looking number.

## Physical acceptance matrix

Every row below is **not yet tested**. Documentation and generated compositions cannot satisfy these gates.

| Scenario | Proof required |
| --- | --- |
| New room saved and app terminated | Reopen offline; verify original mesh counts/bounds, semantic data, measurements, and artifact checksums |
| Same room revisited next day | Restore coordinate alignment; record relocalization time and failures; compare fixed reference features |
| Different light/viewpoint | Show useful guidance; no false aligned overlay; preserve the previous revision through retries |
| New region observed | Add coverage with source-pass provenance; verify existing revision is byte-stable |
| Chair moved or removed | No unqualified current mesh containing a ghost chair; retain unknown/candidate difference until reconciliation is proven |
| Old region not revisited | Label not observed this time; never classify it as removed |
| Tracking fails during a pass | No coordinates from an unaligned segment written into the earlier frame; recover or retain a separate segment |
| Measurements repeated | Compare tape/known dimensions and a reference level across ranges, materials, angles, and devices; separate bias from repeatability |
| Room has missing wall/ceiling | No fabricated closure or unjustified area/volume; incomplete state survives reopening |
| Low disk or interrupted write | Last saved revision remains usable; partial draft is recoverable or explicitly incomplete |
| Missing/corrupt optional world map | Saved visualization works; alignment capability degrades accurately |
| Two devices edit offline | Both revisions survive optional sync; no last-writer data loss; cross-device alignment tested separately |
| Large room / long capture | Profile frame pacing, thermal pressure, peak memory, save duration, and viewer responsiveness on target hardware |
| Export and import | Verify units, transforms, revision/method metadata, omitted assets, and truthful capability flags |

Before public accuracy claims, establish a defined test protocol with an external reference, device/material/distance coverage, error distribution, and clear limits. This is the gate for display precision and any tolerance labels. A successful scan or attractive model is not an accuracy result.

## First implementation investigation

Build the smallest real-device path that captures a mesh and RoomPlan data from a compatible session, saves the independent assets, terminates/relaunches, restores a spatial map, adds another pass, and reviews both. Include the moved-chair and unseen-region cases immediately. The result should settle whether the first release can offer reconciled updates, aligned revision comparison, or a more limited new-pass workflow.

The successful deliverable is a reopened room with inspectable source files and a verified later pass. After that, implement the selected visual composition and the full capture/recovery journey against those real states.
