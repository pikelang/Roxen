// Some debug tools.
//
// $Id: RoxenDebug.pmod,v 1.5 2003/01/20 14:33:31 mast Exp $


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
      if (!has_suffix (new_id, cnt)) new_id += cnt;

      if (sscanf (new_id, "%s(0)[%*d]", string base) == 2) {
	// Try to improve the name. The backtrace typically look like
	// this: ({..., caller 1, caller 2, ObjectMarker(), this
	// function}). Caller 2 is probably in the class containing
	// the _sprintf that produced base, so we use the line number
	// info for caller 1 instead to provide more info.
	array|object bt = backtrace();
	string file;
	int i;
	for (i = -2; i >= -sizeof (bt); i--)
	  if (!!file & !!(file = bt[i][0])) break;
	if (file) {
	  string cwd = getcwd() + "/";
	  if (has_prefix (file, cwd)) file = file[sizeof (cwd)..];
	  new_id = sprintf ("%s(%s:%d)%s", base, file, bt[i][1], cnt);
	}
      }

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
