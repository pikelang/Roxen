//   $Id$

class dims {
  //  Only a wrapper for Pike implementation
  inherit Image.Dims;

  array(int|string) get(string|Stdio.File data)
  {
    array(int|string) res = ::get (data);
    if (!res && stringp(data)) {
      // Let's check if data is a path (backwards compat with 8.0 Image.Dims).
      if (Stdio.File file = Stdio.File(data)) {
	res = ::get(file);
      }
    }

    return res && res[..1];
  }
}
