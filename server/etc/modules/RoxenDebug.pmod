// Some debug tools.
//
// $Id: RoxenDebug.pmod,v 1.4 2001/08/28 21:35:59 mast Exp $


//! Helper to locate leaking objects. Use a line like this to mark a
//! class for tracking:
//!
//! @example
//! RoxenDebug.ObjectMarker __marker = RoxenDebug.ObjectMarker (this_object());

mapping(string:int) object_markers = ([]);

int log_create_destruct = 1;

//!
class ObjectMarker
{
  int count = ++all_constants()->__object_marker_count;
  string id;

  //!
  void create (void|string|object obj)
  {
    if (obj) {
      string new_id = stringp (obj) ? obj : sprintf ("%O", obj);
      string cnt = sprintf ("[%d]", count);
      if (new_id[sizeof (new_id) - sizeof (cnt)..] != cnt) new_id += cnt;
      if (id) {
	if (new_id == id) return;
	if (log_create_destruct)
	  if (object_markers[id] > 0) werror ("rename  %s -> %s\n", id, new_id);
	  else werror ("rename  ** %s -> %s\n", id, new_id);
	if (--object_markers[id] <= 0) m_delete (object_markers, id);
      }
      else
	if (log_create_destruct) werror ("create  %s\n", new_id);
      id = new_id;
      object_markers[id]++;
    }
  }

  void destroy()
  {
    if (id) {
      if (log_create_destruct)
	if (object_markers[id] > 0) werror ("destroy %s\n", id);
	else werror ("destroy ** %s\n", id);
      if (--object_markers[id] <= 0) m_delete (object_markers, id);
    }
  }

  string _sprintf()
  {
    return "RoxenDebug.ObjectMarker(" + id + ")";
  }
}

//!
string report_leaks()
{
  string res = "leaks: " + sort (indices (object_markers)) * ",\n       " + "\n";
  object_markers = ([]);
  return res;
}
