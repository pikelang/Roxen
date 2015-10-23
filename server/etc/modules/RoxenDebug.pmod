// Some debug tools.
//
// $Id$


//! Helper to locate leaking objects. Use a line like this to mark a
//! class for tracking:
//!
//! @example
//! RoxenDebug.ObjectMarker __marker = RoxenDebug.ObjectMarker (this_object());

mapping(string:int) object_markers = ([]);
mapping(string:string) object_create_places = ([]);

int log_create_destruct = 1;

//!
class ObjectMarker
{
  int count = ++all_constants()->__object_marker_count;
  string id;
  int flags;

  protected void debug_msg (array bt, int ignore_frames,
			    string msg, mixed... args)
  {
    if (sizeof (args)) msg = sprintf (msg, @args);

    string file;
    int i;

  find_good_frame: {
      for (i = -1 - ignore_frames; i >= -sizeof (bt); i--)
	if ((file = bt[i][0]) && bt[i][1] && bt[i][2] &&
	    !(<"__INIT", "create", "ObjectMarker">)[function_name(bt[i][2])])
	  break find_good_frame;

      for (i = -1 - ignore_frames; i >= -sizeof (bt); i--)
	if ((file = bt[i][0]) &&
	    !(<"__INIT", "create", "ObjectMarker">)[
	      function_name(bt[i][2] || debug_msg)])
	  break find_good_frame;

      for (i = -1 - ignore_frames; i >= -sizeof (bt); i--)
	if ((file = bt[i][0]))
	  break find_good_frame;
    }

    if (file) {
      string cwd = getcwd() + "/";
      if (has_prefix (file, cwd)) file = file[sizeof (cwd)..];
      werror ("%s:%d: %s", file, bt[i][1], msg);
    }
    else werror (msg);
  }

  //!
  void create (void|string|object obj, void|int _flags)
  {
    flags = _flags;
    if (obj) {
      string new_id = stringp (obj) ? obj : sprintf ("%O", obj);
      string cnt = sprintf ("[%d]", count);
      if (!has_suffix (new_id, cnt)) new_id += cnt;

      if (id) {
	if (new_id == id) return;
	if (log_create_destruct)
	  if (object_markers[id] > 0)
	    debug_msg (backtrace(), 1, "rename %s -> %s\n", id, new_id);
	  else
	    debug_msg (backtrace(), 1, "rename ** %s -> %s\n", id, new_id);
	if (--object_markers[id] <= 0) {
	  m_delete (object_markers, id);
	  m_delete (object_create_places, id);
	}
      }
      else
	if (log_create_destruct)
	  debug_msg (backtrace(), 1, "create %s\n", new_id);

      id = new_id;
      object_markers[id]++;
      object_create_places[id] = describe_backtrace (backtrace());
    }
  }

  void destroy()
  {
    if (global::this) {
      if (id) {
	if (log_create_destruct)
	  if (object_markers[id] > 0) debug_msg (backtrace(), 1, "destroy %s\n", id);
	  else debug_msg (backtrace(), 1, "destroy ** %s\n", id);
	if (--object_markers[id] <= 0) {
	  m_delete (object_markers, id);
	  m_delete (object_create_places, id);
	}
      }
      if (flags && log_create_destruct) {
	werror("destructing...\n"
	       "%s\n", describe_backtrace(backtrace()));
      }
    }
  }

  string _sprintf()
  {
    return "RoxenDebug.ObjectMarker(" + id + ")";
  }
}

//!
string report_leaks (void|int clear)
{
  if (!sizeof (object_markers))
    return "";
  string res = "leaks: " +
    sort (map (indices (object_markers),
	       lambda (string id) {
		 if (string bt = object_create_places[id])
		   return id + ":\n         " +
		     replace (bt[..sizeof (bt) - 2], "\n", "\n         ");
		 else
		   return id;
	       })) * "\n       " +
    "\n";
  if (clear) object_markers = ([]);
  return res;
}
