library utility;

/// Allow a reference to an object of primitive type to be stored
class ByRef<T> {
  /// Construct new [ByRef]
  ByRef(this.value);

  /// Value of this [ByRef]
  T value;
}
