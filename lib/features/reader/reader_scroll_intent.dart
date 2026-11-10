/// Requires deliberate finger/mouse scrolling before changing reading controls.
class ReaderScrollIntent {
  double _distance = 0;
  void reset() => _distance = 0;

  bool? update(double delta, double offset, {required bool visible}) {
    if (offset <= 12 && delta < 0) {
      reset();
      return true;
    }
    if (delta == 0) return null;
    if ((_distance > 0 && delta < 0) || (_distance < 0 && delta > 0)) reset();
    _distance += delta;
    // A longer upward movement prevents small corrections from revealing menus.
    if (!visible && _distance <= -80) {
      reset();
      return true;
    }
    if (visible && _distance >= 48) {
      reset();
      return false;
    }
    return null;
  }
}
