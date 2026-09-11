# iCloud portability captures

Native simulator captures from September 10, 2026. All readings and imported setup references are labeled fixtures. The UI test account reader deliberately returns unavailable; these images are not proof of cloud transfer or physical Bluetooth detection.

- `icloud-default-off.png`: opt-in is off, with local storage status and the purchase/library distinction.
- `icloud-unavailable.png`: account failure returns to off without blocking instruments.
- `icloud-setup-reference.png`: dark appearance; original threshold/history and an unconnected local device picker.
- `icloud-setup-connected.png`: explicit link to the locally saved fixture, with a next test action.
- `icloud-connected-group-result.png`: the imported group uses the chosen local radio; visibly marked Sample result.
- `icloud-largest-text.png` and `icloud-largest-empty.png`: largest accessibility text with native scrolling and reachable controls.
- The `-ipad` captures show the tablet sheet's initial largest-text position and the subsequent Bluetooth-reference empty state. The initial tablet capture is context, not a picture of the toggle.

Capture hashes and the exact test-result source are recorded in [the validation receipt](../../validation/icloud-evidence.json). Phone captures include the final footer copy that explicitly names groups.
