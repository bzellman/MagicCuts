## verdict

- Motion / scroll amendment — partial: the supplied second-pass frames retain a single control instance and the settled compact state remains intact, but the raw iPad frames still crop the instrument label/source group to fragments or hide retained controls mid-transition. The original requirement for one continuously legible control group throughout fold and unfold is not resolved.

## remaining

Remove the intermediate clipping and control disappearance from the interpolated Layout transition, then recapture phone and tablet raw frames in which Instrument, Source, Room, and Settings stay visibly represented and legible for the entire mutation. Regression: `phone/pro-largest-text.png` and `tablet/pro-largest-text.png` show the fixed Room symbol colliding with the Room label and clipping at the header's left edge; restore a correctly sized, separated accessibility layout.

disposition: fix
