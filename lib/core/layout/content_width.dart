/// How wide a block of content is allowed to get before it stops being
/// readable and starts being a stretched phone layout.
///
/// These used to be eight different literals scattered across the screens
/// (640, 640, 680, 720, 720, 760, 880, 880), so two screens showing the same
/// kind of content disagreed about it. Pick the role, not a number.
abstract final class ContentWidth {
  /// One column of prose or list rows — the measure that stays comfortable
  /// to read.
  static const double reading = 680;

  /// Forms and settings: wider than prose because rows are label + control.
  static const double form = 720;

  /// A centered modal card over a scrim — read at a glance rather than worked
  /// through, so it stops short of a form.
  static const double dialog = 560;

  /// One primary button standing alone (Play, Next, Start the pack). On a
  /// phone such a button fills its row; on a tablet a full-width one became a
  /// 700–1000dp slab, so past this it stays button-sized and centred.
  static const double button = 340;

  /// Multi-column grids of cards or thumbnails.
  static const double grid = 880;

  /// Wide-window composition: two-column browse layouts and dense grids on
  /// expanded-and-up windows. Wide enough that a desktop or iPad-landscape
  /// screen stops reading as a stretched phone column, short enough that a
  /// 1200-class content area keeps real margins.
  static const double wide = 1120;
}
