// Prototype for emit plugin response object.

class EmitObject {

  private mapping(string:mixed) next_row;

  //! Returns a new set of variables to be used in
  //! the emit loop.
  mapping(string:mixed) get_row() {

    if(next_row) {
      mapping(string:mixed) current = next_row;
      next_row = 0;
      return current;
    }
    return really_get_row();
  }

  //! Returns the next element and increments the
  //! element counter.
  static mapping(string:mixed) really_get_row() { }

  //! Remove the next value.
  void skip_row() {
    if(next_row) {
      next_row = 0;
      return;
    }
    really_get_row();
  }

  //! Returns the next element that get_row will
  //! return.
  mapping(string:mixed) peek() {
    if(next_row) return next_row;
    next_row = really_get_row();
    return next_row;
  }

  //! Returns the number of rows left. It does
  //! however destroy the resulting values, so
  //! the object is rendered useless after this
  //! method is called.
  int num_rows_left() {
    int num = !!next_row;
    while(really_get_row()) num++;
    return num;
  }
}
