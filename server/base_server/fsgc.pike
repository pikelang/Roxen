//
// Unified file system garbage collector.
//
// 2013-09-12 Henrik Grubbström
//

#if constant(Filesystem.Monitor.basic)

// #define FSGC_DEBUG
// #define FSGC_PRETEND

#ifdef FSGC_DEBUG
#define GC_WERR(X...)	werror(X)
#else
#define GC_WERR(X...)
#endif

/* Some notes:
 *
 *   There are multiple data for a file that may affect the garbage policy:
 *
 *     * The age of the file.
 *
 *     * The size of the file.
 *
 *   Garbage collection for a root may be triggered by several factors:
 *
 *     * A maxium age for a file has been reached.
 *
 *     * Too many files under a root.
 *
 *     * The total size of the files under a root is too large.
 *
 *   Symlinks are not followed and not garbage collected due
 *   to the inherent risks of escaping directory structures
 *   and/or removing manually added stuff.
 */

//! Filesystem garbage collector for a single root directory.
class FSGarb
{
  inherit Filesystem.Monitor.basic : basic;

  int num_files;
  int total_size;

  string modid;
  string root;
  int max_age;
  int max_files;
  int max_size;

  mapping(string:object) handle_lookup = ([]);
  ADT.Priority_queue pending_gc = ADT.Priority_queue();

  //! If set, move files to this directory instead of deleting them.
  //!
  //! If set to @[root] or @expr{""@} keep the files as is.
  string quarantine;

  protected int rm(string path)
  {
    GC_WERR("FSGC: Zap %O\n", path);
    if (quarantine) {
      if ((quarantine == root) || (quarantine == "")) return 0;
      if (!has_prefix(path, root)) return 0;
      string rel = path[sizeof(root)..];

      // First try the trivial case.
      if (mv(path, quarantine + rel)) return 1;

      string dirs = dirname(rel);
      if (sizeof(dirs)) {
	if (Stdio.mkdirhier(quarantine + dirs)) {
	  // Try again with the directory existing.
	  if (mv(path, quarantine + rel)) return 1;
	}
      }

      // Different filesystems?
      if (Stdio.cp(path, quarantine + rel)) {
	return predef::rm(path);
      }
      werror("FSGC: Failed to copy file %O to %O: %s.\n",
	     path, quarantine + rel, strerror(errno()));
      return 0;
    } else {
      return predef::rm(path);
    }
  }

  void check_threshold()
  {
    GC_WERR("FSGC: Checking thresholds...\n"
	    "      total_size: %d max_size: %d\n"
	    "      num_files: %d max_files: %d\n",
	    total_size, max_size,
	    num_files, max_files);

    while ((max_size && (total_size > max_size)) ||
	   (max_files && (num_files > max_files))) {
      GC_WERR("FSGC: Filesystem limits exceeded forcing early removal.\n");
      if (!zap_one_file()) break;
    }
  }

  protected int zap_one_file()
  {
    if (!sizeof(pending_gc)) return 0;

    // Pop the next pending file from the queue.
    Monitor m = pending_gc->pop();
    m_delete(handle_lookup, m->path);

    // Account for the deletion immediately, and
    // make sure it isn't counted twice.
    int bytes = m->st->size;
    m->st->size = 0;
    m->st->isreg = 0;

    GC_WERR("Deleting file %O...\n", m->path);
    if (rm(m->path)) {
      num_files--;
      total_size -= bytes;

      // Make sure the deletion is notified properly soon.
      m->next_poll = time(1);
      monitor_queue->adjust(m);
    } else {
      GC_WERR("Failed to delete file %O: %s\n",
	      m->path, strerror(errno()));
      // Restore the state in case the file is altered externally.
      m->st->size = bytes;
      m->st->isreg = 1;
    }
    return 1;
  }

  int st_to_pri(Stdio.Stat st)
  {
    return st->mtime - st->size / 1024;
  }

  protected void remove_pending(Monitor m)
  {
    // Register us for threshold-based deletion.
    object handle = m_delete(handle_lookup, m->path);
    if (handle) {
      pending_gc->adjust_pri(handle, -0x80000000);
      pending_gc->pop();
    }
  }

  protected class Monitor {
    inherit basic::Monitor;

    protected void create(string path,
			  MonitorFlags flags,
			  int max_dir_check_interval,
			  int file_interval_factor,
			  int stable_time)
    {
      ::create(path, flags, max_dir_check_interval,
	       file_interval_factor, stable_time);
      GC_WERR("%O->create(%O, %O, %O, %O, %O)\n",
	      this_object(), path, flags, max_dir_check_interval,
	      file_interval_factor, stable_time);
    }

    void check_for_release(int mask, int flags)
    {
      GC_WERR("%O->check_for_relase(0x%x, 0x%x)\n",
	      this_object(), mask, flags);
      ::check_for_release(mask, flags);
      if (!monitors[path]) {
	// We've been relased.
	// Make sure to update our parent (if any) soon.
	array a = path/"/";
	Monitor m = monitors[canonic_path(a[..sizeof(a)-2]*"/")];
	if (m) {
	  GC_WERR("Waking up our parent dir: %O\n", m);
	  m->next_poll = time(1)-1;
	  monitor_queue->adjust(m);
	}
      }
    }

    protected void file_exists(string path, Stdio.Stat st)
    {
      ::file_exists(path, st);
      // Make sure we get the stable change callback...
      last_change = st->mtime;

      if (st->isreg) {
	num_files++;
	total_size += st->size;

	// Register us for threadhold-based deletion.
	handle_lookup[path] = pending_gc->push(st_to_pri(st), this);

	check_threshold();
      }
    }

    // NB: Needs to be visible so that reconfigure() can call it.
    void update(Stdio.Stat st)
    {
      int delta = max_dir_check_interval || basic::max_dir_check_interval;
      if (!next_poll) {
	// Attempt to distribute polls evenly at startup.
	delta = 1 + random(delta);
	if (st) {
	  last_change = st->mtime;
	}
      }

      ::update(st);

      // We're only interested in stable time, so there's no reason
      // to scan as frequently as the default implementation.

      if (last_change <= time(1)) {
	// Time until stable.
	int d = last_change + (stable_time || basic::stable_time) - time(1);

	GC_WERR("%O: last: %s, d: %d, delta: %d\n",
		this_object(), ctime(last_change) - "\n", d, delta);
	if (d < 0) d = 1;
	if (d < delta) delta = d;
      }
      next_poll = time(1) + (delta || 1);
      GC_WERR("%O->update(%O) ==> next: %s\n",
	      this_object(), st, ctime(next_poll) - "\n");
      monitor_queue->adjust(this);
    }

    protected string _sprintf(int c)
    {
      return sprintf("FSGarb.Monitor(%O, %O, last: %d, next: %s, st: %O)",
		     path, flags, last_change, ctime(next_poll) - "\n", st);
    }

    int(0..1) check(MonitorFlags|void flags)
    {
      int(0..1) ret = ::check(flags);
      return ret;
    }

    int(0..1) status_change(Stdio.Stat old_st, Stdio.Stat st,
			    MonitorFlags old_flags, MonitorFlags flags)
    {
      GC_WERR("Status change %O(0x%x) ==> %O(0x%x) for %O!\n",
	      old_st, old_flags, st, flags, this_object());
      int res = ::status_change(old_st, st, old_flags, flags);
      if (st->isdir && (flags & MF_RECURSE)) {
	foreach(files, string file) {
	  file = canonic_path(Stdio.append_path(path, file));
	  if (!monitors[file]) {
	    // Lost update due to race-condition:
	    //
	    //   Exist ==> Deleted ==> Exists
	    //
	    // with no update of directory inbetween.
	    //
	    // Create the lost submonitor again.
	    res = 1;
	    monitor(file, old_flags | MF_AUTO | MF_HARD,
		    max_dir_check_interval,
		    file_interval_factor,
		    stable_time);
	    monitors[file]->check();
	  }
	}
      }

      num_files += st->isreg - old_st->isreg;

      if (old_st->isreg) {
	total_size -= old_st->size;

	if (!st->isreg) {
	  remove_pending(this);
	}
      }
      if (st->isreg) {
	total_size += st->size;

	// Register us for threshold-based deletion.
	if (!old_st->isreg) {
	  handle_lookup[path] = pending_gc->push(st_to_pri(st), this);
	} else {
	  object handle = handle_lookup[path];
	  if (handle && (st_to_pri(st) != st_to_pri(old_st))) {
	    pending_gc->adjust_pri(handle, st_to_pri(st));
	  }
	}
      }

      check_threshold();
      return res;
    }

    void file_created(string path, Stdio.Stat st)
    {
      GC_WERR("File %O %O created (%O).\n", path, st, this_object());

      if (st->isreg) {
	num_files++;
	total_size += st->size;

	// Register us for threshold-based deletion.
	handle_lookup[path] = pending_gc->push(st_to_pri(st), this);

	check_threshold();
      }
    }

    void file_deleted(string path, Stdio.Stat old_st)
    {
      GC_WERR("File %O %O deleted (%O).\n", path, old_st, this_object());

      if (old_st->isreg) {
	num_files--;
	total_size -= old_st->size;

	remove_pending(this);

	check_threshold();
      }
    }
  }

  protected void create(string modid, string path, int max_age,
			int|void max_size, int|void max_files,
			string|void quarantine)
  {
    GC_WERR("FSGC: Max age: %d\n", max_age);
    GC_WERR("FSGC: Max size: %d\n", max_size);
    GC_WERR("FSGC: Max files: %d\n", max_files);

    this_program::modid = modid;

    this_program::max_age = max_age;
    this_program::max_size = max_size;
    this_program::max_files = max_files;

    root = canonic_path(path);

    if (quarantine) {
      if (sizeof(quarantine)) {
	quarantine = canonic_path(quarantine);
      }
      this::quarantine = quarantine;
    }

    ::create(max_age/file_interval_factor, 0, max_age);

    // Workaround for too strict type-check in Pike 7.8.
    int flags = 3;

    monitor(root, flags);
  }

  void stable_data_change(string path, Stdio.Stat st)
  {
    GC_WERR("FSGC: Deleting stale file: %O\n", path);
    if (path == root) return;
    // Override accelerated stable change notification.
    if (st->mtime > time(1) - stable_time) {
      GC_WERR("FSGC: Keeping file: %O\n", path);
      return;
    }
    rm(path);
  }

  void reconfigure(int new_max_age, int|void new_max_size,
		   int|void new_max_files)
  {
    if (!zero_type(new_max_size)) {
      GC_WERR("FSGC: New max size: %d\n", new_max_size);
      max_size = new_max_size;
    }
    if (!zero_type(new_max_files)) {
      GC_WERR("FSGC: New max files: %d\n", new_max_files);
      max_files = new_max_files;
    }
    if (new_max_age != max_age) {
      GC_WERR("FSGC: New max age: %d\n", new_max_age);
      this_program::max_age = new_max_age;
      int old_stable_time = stable_time;
      set_max_dir_check_interval(stable_time = new_max_age);
      if (stable_time < old_stable_time) {
	// We need to adjust the scan times for the monitors.
	foreach(values(monitors), Monitor m) {
	  m->next_poll = 0;
	  m->update(m->st);
	}
      }
    }

    check_threshold();
  }

  int check(mixed ... args)
  {
    int res = ::check(@args);
    GC_WERR("FSGC: check(%{%O, %}) ==> %O\n", args, res);
    return res;
  }

  protected string _sprintf(int c, mapping|void opts)
  {
    return sprintf("FSGarb(%O, %d)", root, stable_time);
  }

  array(Stdio.Stat) get_stats()
  {
    return filter(values(monitors)->st,
		  lambda(Stdio.Stat st) {
		    return st && st->isreg;
		  });
  }
}

mapping(string:FSGarb) fsgarbs = ([]);

Thread.Thread meta_fsgc_thread;

void meta_fsgc()
{
  // Sleep a bit to avoid the startup race.
  sleep(60);
  while(meta_fsgc_thread) {
    int max_sleep = 60;
    foreach(fsgarbs; string id; FSGarb g) {
      int seconds = g && g->check();
      if (seconds < max_sleep) max_sleep = seconds;
    }
    if (max_sleep < 1) max_sleep = 1;
    GC_WERR("FSGC: Sleeping %d seconds...\n", max_sleep);
    while(meta_fsgc_thread && max_sleep--) {
      sleep(1);
    }
  }
}

//! Wrapper keeping a @[FSGarb] alive.
//!
//! When this object is destructed (eg by refcount), the corresponding
//! @[FSGarb] will be killed. This is to make sure stale @[FSGarb]s aren't
//! left running after module reloads or reconfigurations.
class FSGarbWrapper(string id)
{
  protected void destroy()
  {
    GC_WERR("FSGC: FSGarbWrapper %O destructed.\n", id);
    FSGarb g = m_delete(fsgarbs, id);
    if (g) destruct(g);
  }

  protected string _sprintf(int c, mapping|void opts)
  {
    return sprintf("FSGarbWrapper(%O)", id);
  }

  void reconfigure(int max_age, int|void max_size, int|void max_files)
  {
    FSGarb g = fsgarbs[id];
    if (g) g->reconfigure(max_age, max_size, max_files);
  }
}

FSGarbWrapper register_fsgarb(string modid, string path, int max_age,
			      int|void max_size, int|void max_files,
			      string|void quarantine)
{
  if ((path == "") || (path == "/") || (max_age <= 0)) return 0;
  string id = modid + "\0" + path + "\0" + gethrtime();
  FSGarb g = FSGarb(modid, path, max_age, max_size, max_files,
		    quarantine);
  fsgarbs[id] = g;
  GC_WERR("FSGC: Register garb on %O ==> id: %O\n", path, id);
  return FSGarbWrapper(id);
}

void name_thread(object thread, string name);

protected void start_fsgarb()
{
  meta_fsgc_thread = Thread.Thread(meta_fsgc);
  name_thread(meta_fsgc_thread, "Filesystem GC");
}

protected void stop_fsgarb()
{
  Thread.Thread th = meta_fsgc_thread;
  if (th) {
    meta_fsgc_thread = UNDEFINED;
    th->wait();
    name_thread(th, UNDEFINED);
  }
}

#endif /* Filesystem.Monitor.basic */
