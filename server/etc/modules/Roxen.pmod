/*
 * $Id: Roxen.pmod,v 1.7 1999/05/16 15:36:46 grubba Exp $
 *
 * Various helper functions.
 *
 * Henrik Grubbström 1999-05-03
 */

/*
 * TODO:
 *
 * o Quota: Fix support for the index file.
 *
 */

#ifdef QUOTA_DEBUG
#define QD_WRITE(X)	werror(X)
#else /* !QUOTA_DEBUG */
#define QD_WRITE(X)
#endif /* QUOTA_DEBUG */

class QuotaDB
{
#if constant(create_thread)
  object(Thread.Mutex) lock = Thread.Mutex();
#define LOCK()		mixed key__; catch { _key = lock->lock(); }
#define UNLOCK()	do { if (key__) destruct(key__); } while(0)
#else /* !constant(create_thread) */
#define LOCK()
#define UNLOCK()
#endif /* constant(create_thread) */

  constant READ_BUF_SIZE = 256;
  constant CACHE_SIZE_LIMIT = 512;

  string base;

  object catalog_file;
  object data_file;

  mapping(string:int) new_entries_cache = ([]);
  mapping(string:object) active_objects = ([]);

  array(int) index;
  array(string) index_acc;
  int acc_scale;

  int next_offset;

  static class QuotaEntry
  {
    string name;
    int data_offset;

    static int usage;
    static int quota;

    static void store()
    {
      LOCK();

      QD_WRITE(sprintf("QuotaEntry::store(): Usage for %O is now %O(%O)\n",
		       name, usage, quota));

      data_file->seek(data_offset);
      data_file->write(sprintf("%4c", usage));

      UNLOCK();
    }

    static void read()
    {
      LOCK();

      data_file->seek(data_offset);
      string s = data_file->read(4);

      usage = 0;
      sscanf(s, "%4c", usage);

      QD_WRITE(sprintf("QuotaEntry::read(): Usage for %O is %O(%O)\n",
		       name, usage, quota));

      UNLOCK();
    }

    void create(string n, int d_o, int q)
    {
      QD_WRITE(sprintf("QuotaEntry(%O, %O, %O)\n", n, d_o, q));

      name = n;
      data_offset = d_o;
      quota = q;

      read();
    }

    int check_quota(string uri, int amount)
    {
      QD_WRITE(sprintf("QuotaEntry::check_quota(%O, %O): usage:%d(%d)\n",
		       uri, amount, usage, quota));

      if (!quota) {
	// No quota at all.
	return 0;
      }

      if (amount == 0x7fffffff) {
	// Workaround for FTP.
	return 1;
      }

      return(usage + amount <= quota);
    }

    int allocate(string uri, int amount)
    {
      QD_WRITE(sprintf("QuotaEntry::allocate(%O, %O): usage:%d => %d(%d)\n",
		       uri, amount, usage, usage + amount, quota));

      usage += amount;

      store();

      return(usage <= quota);
    }

    int deallocate(string uri, int amount)
    {
      return(allocate(uri, -amount));
    }

    int get_usage(string uri)
    {
      return usage;
    }

    void set_usage(string uri, int amount)
    {
      usage = amount;

      store();
    }

#if !constant(set_weak_flag)
    static int refs;

    void add_ref()
    {
      refs++;
    }

    void free_ref()
    {
      if (!(--refs)) {
	destruct();
      }
    }
  }

  static class QuotaProxy
  {
    static object(QuotaEntry) master;

    function(string, int:int) check_quota;
    function(string, int:int) allocate;
    function(string, int:int) deallocate;
    function(string, int:void) set_usage;
    function(string:int) get_usage;

    void create(object(QuotaEntry) m)
    {
      master = m;
      master->add_ref();
      check_quota = master->check_quota;
      allocate = master->allocate;
      deallocate = master->deallocate;
      set_usage = master->set_usage;
      get_usage = master->get_usage;
    }

    void destroy()
    {
      master->free_ref();
    }
#endif /* !constant(set_weak_flag) */
  }

  static object read_entry(int offset, int|void quota)
  {
    QD_WRITE(sprintf("QuotaDB::read_entry(%O, %O)\n", offset, quota));

    catalog_file->seek(offset);

    string data = catalog_file->read(READ_BUF_SIZE);

    if (data == "") {
      QD_WRITE(sprintf("QuotaDB::read_entry(%O, %O): At EOF\n",
		       offset, quota));

      return 0;
    }

    int len;
    int data_offset;
    string key;

    sscanf(data[..7], "%4c%4c", len, data_offset);
    if (len > sizeof(data)) {
      key = data[8..] + catalog_file->read(len - sizeof(data));

      len -= 8;

      if (sizeof(key) != len) {
	error(sprintf("Failed to read catalog entry at offset %d.\n"
		      "len: %d, sizeof(key):%d\n",
		      offset, len, sizeof(key)));
      }
    } else {
      key = data[8..len-1];
      catalog_file->seek(offset + 8 + sizeof(key));
    }

    return QuotaEntry(key, data_offset, quota);
  }

  static object open(string fname, int|void create_new)
  {
    object f = Stdio.File();
    string mode = create_new?"rwc":"rw";

    if (!f->open(fname, mode)) {
      error(sprintf("Failed to open quota file %O.\n", fname));
    }
    if (f->try_lock && !f->try_lock()) {
      error(sprintf("Failed to lock quota file %O.\n", fname));
    }
    return(f);
  }

  static void init_index_acc()
  {
    /* Set up the index accellerator.
     * sizeof(index_acc) ~ sqrt(sizeof(index))
     */
    acc_scale = 1;
    if (sizeof(index)) {
      int i = sizeof(index)/2;

      while (i) {
	i /= 4;
	acc_scale <<= 1;
      }
    }
    index_acc = allocate(sizeof(index)/acc_scale);

    QD_WRITE(sprintf("QuotaDB()::init_index_acc(): "
		     "sizeof(index):%d, sizeof(index_acc):%d acc_scale:%d\n",
		     sizeof(index), sizeof(index_acc), acc_scale));
  }

  void rebuild_index()
  {
    // FIXME: Actually make an index file.
    array(string) new_keys = sort(indices(new_entries_cache));

    int prev;
    array(int) new_index = ({});

    foreach(new_keys, string key) {
      int lo;
      int hi = sizeof(index_acc);
      if (hi) {
	do {
	  // Loop invariants:
	  //   hi is an element > key.
	  //   lo-1 is an element < key.

	  int probe = (lo + hi)/2;

	  if (!index_acc[probe]) {
	    object e = read_entry(index[probe * acc_scale]);

	    index_acc[probe] = e->name;
	  }
	  if (index_acc[probe] < key) {
	    lo = probe + 1;
	  } else if (index_acc[probe] > key) {
	    hi = probe;
	  } else {
	    /* Found */
	    // Shouldn't happen...
	    break;
	  }
	} while(lo < hi);

	if (lo < hi) {
	  // Found...
	  // Shouldn't happen, but...
	  // Skip to the next key...
	  continue;
	}
	hi *= acc_scale;
	lo = hi - acc_scale;

	do {
	  // Same loop invariants as above.

	  int probe = (lo + hi)/2;
	  object e = read_entry(index[probe]);
	  if (e->name < key) {
	    lo = probe + 1;
	  } else if (e->name > key) {
	    hi = probe;
	  } else {
	    /* Found */
	    // Shouldn't happen...
	    break;
	  }
	} while (lo < hi);
	if (lo < hi) {
	  // Found...
	  // Shouldn't happen, but...
	  // Skip to the next key...
	  continue;
	}
	new_index += index[prev..hi-1] + ({ new_entries_cache[key] });
	prev = hi;
      } else {
	new_index += ({ new_entries_cache[key] });
      }
    }

    LOCK();

    object index_file = open(base + ".index.new", 1);
    string to_write = sprintf("%@4c", new_index);
    if (index_file->write(to_write) != sizeof(to_write)) {
      index_file->close();
      rm(base + ".index.new");
    } else {
      mv(base + ".index.new", base + ".index");
    }

    index = new_index;
    init_index_acc();

    UNLOCK();

    foreach(new_keys, string key) {
      m_delete(new_entries_cache, key);
    }
  }

  static object low_lookup(string key, int quota)
  {
    QD_WRITE(sprintf("QuotaDB::low_lookup(%O, %O)\n", key, quota));

    int cat_offset;

    if (!zero_type(cat_offset = new_entries_cache[key])) {
      QD_WRITE(sprintf("QuotaDB::low_lookup(%O, %O): "
		       "Found in new entries cache.\n", key, quota));
      return read_entry(cat_offset, quota);
    }

    /* Try the index file. */

    /* First use the accellerated index. */
    int lo;
    int hi = sizeof(index_acc);
    if (hi) {
      do {
	// Loop invariants:
	//   hi is an element that is > key.
	//   lo-1 is an element that is < key.
	int probe = (lo + hi)/2;

	QD_WRITE(sprintf("QuotaDB:low_lookup(%O): "
			 "In acc: lo:%d, probe:%d, hi:%d\n",
			 key, lo, probe, hi));

	if (!index_acc[probe]) {
	  object e = read_entry(index[probe * acc_scale], quota);

	  index_acc[probe] = e->name;

	  if (key == e->name) {
	    /* Found in e */
	    QD_WRITE(sprintf("QuotaDB:low_lookup(%O): In acc: Found at %d\n",
			     key, probe * acc_scale));
	    return e;
	  }
	}
	if (index_acc[probe] < key) {
	  lo = probe + 1;
	} else if (index_acc[probe] > key) {
	  hi = probe;
	} else {
	  /* Found */
	  QD_WRITE(sprintf("QuotaDB:low_lookup(%O): In acc: Found at %d\n",
			   key, probe * acc_scale));
	  return read_entry(index[probe * acc_scale], quota);
	}
      } while(lo < hi);
      // At this point hi is the first element that is > key.
      // Not in the accellerated index.

      if (hi) {
	// Go to disk

	hi *= acc_scale;
	lo = hi - acc_scale;
	do {
	  // Same loop invariant as above.

	  int probe = (lo + hi)/2;

	  QD_WRITE(sprintf("QuotaDB:low_lookup(%O): lo:%d, probe:%d, hi:%d\n",
			   key, lo, probe, hi));

	  object e = read_entry(index[probe], quota);
	
	  if (e->name < key) {
	    lo = probe + 1;
	  } else if (e->name > key) {
	    hi = probe;
	  } else {
	    /* Found */
	    QD_WRITE(sprintf("QuotaDB:low_lookup(%O): Found at %d\n",
			     key, probe));
	    return e;
	  }
	} while (lo < hi);
      }
    }

    QD_WRITE(sprintf("QuotaDB::low_lookup(%O): Not found\n", key));

    return 0;
  }

  object lookup(string key, int quota)
  {
    QD_WRITE(sprintf("QuotaDB::lookup(%O, %O)\n", key, quota));

    LOCK();

    object res;

    if (res = active_objects[key]) {
      QD_WRITE(sprintf("QuotaDB::lookup(%O, %O): User in active objects.\n",
		       key, quota));

#if constant(set_weak_flag)
      return res;
#else /* !constant(set_weak_flag) */
      return QuotaProxy(res);
#endif /* constant(set_weak_flag) */
    }
    if (res = low_lookup(key, quota)) {
      active_objects[key] = res;

#if constant(set_weak_flag)
      return res;
#else /* !constant(set_weak_flag) */
      return QuotaProxy(res);
#endif /* constant(set_weak_flag) */
    }

    QD_WRITE(sprintf("QuotaDB::lookup(%O, %O): New user.\n", key, quota));

    // Search to EOF.
    data_file->seek(-1);
    data_file->read(1);

    catalog_file->seek(next_offset);

    // We should now be at EOF.

    int data_offset = data_file->tell();

    // Initialize.
    if (data_file->write(sprintf("%4c", 0)) != 4) {
      error(sprintf("write() failed for quota data file!\n"));
    }
    string entry = sprintf("%4c%4c%s", sizeof(key)+8, data_offset, key);

    if (catalog_file->write(entry) != sizeof(entry)) {
      error(sprintf("write() failed for quota catalog file!\n"));
    }

    new_entries_cache[key] = next_offset;
    next_offset = catalog_file->tell();

    if (sizeof(new_entries_cache) > CACHE_SIZE_LIMIT) {
      rebuild_index();
    }

    // low_lookup will always succeed at this point.
    return low_lookup(key, quota);
  }

  void create(string base_name, int|void create_new)
  {
    base = base_name;

    catalog_file = open(base_name + ".cat", create_new);
    data_file = open(base_name + ".data", create_new);
    object index_file = open(base_name + ".index", 1);

#if constant(set_weak_flag)
    set_weak_flag(active_objects, 1);
#endif /* constant(set_weak_flag) */

    /* Initialize the new_entries table. */
    array index_st = index_file->stat();
    if (!index_st || !sizeof(index_st)) {
      error(sprintf("stat() failed for quota index file!\n"));
    }
    array data_st = data_file->stat();
    if (!data_st || !sizeof(data_st)) {
      error(sprintf("stat() failed for quota data file!\n"));
    }
    if (index_st[1] < 0) {
      error("quota index file isn't a regular file!\n");
    }
    if (data_st[1] < 0) {
      error("quota data file isn't a regular file!\n");
    }
    if (data_st[1] < index_st[1]) {
      error("quota data file is shorter than the index file!\n");
    }
    if (index_st[1] & 3) {
      error("quota index file has odd length!\n");
    }
    if (data_st[1] & 3) {
      error("quota data file has odd length!\n");
    }

    /* Read the index, and find the last entry in the catalog file.
     */
    int i;
    array(string) index_str = index_file->read()/4;
    index = allocate(sizeof(index_str));

    if (sizeof(index_str) && (sizeof(index_str[-1]) != 4)) {
      error("Truncated read of the index file!\n");
    }

    foreach(index_str, string offset_str) {
      int offset;
      sscanf(offset_str, "%4c", offset);
      index[i++] = offset;
      if (offset > next_offset) {
	next_offset = offset;
      }
    }

    init_index_acc();

    if (sizeof(index)) {
      /* Skip past the last entry in the catalog file */
      mixed entry = read_entry(next_offset);
      next_offset = catalog_file->tell();
    }

    if (index_st[1] < data_st[1]) {
      /* Put everything else in the new_entries_cache */
      while (mixed entry = read_entry(next_offset)) {
	new_entries_cache[entry->name] = next_offset;
	next_offset = catalog_file->tell();
      }

      /* Clean up the index. */
      rebuild_index();
    }
  }
}
