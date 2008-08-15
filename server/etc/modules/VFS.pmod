//! Utility functions for the virtual filesystem in Roxen. Contains
//! functions that otherwise tend to get reinvented a few times per
//! module.




protected Stat stat( string file, RequestID id )
{
  int oi = id->misc->internal_get;
  id->misc->internal_get = 1;
  Stat s = id->conf->stat_file( file, id );
  id->misc->internal_get = oi;
  return s;
}


string normalize_path( string path )
//! Normalize the path in 'path'. Does ../ and ./ calculations, if
//! running on NT or if the start-script is started with
//! --strip-backslash, \ characters are changed to /.
{
  if( strlen( path ) )
  {
    int ss = (<'/','\\'>)[ path[0] ];
    path = combine_path_unix( "/",
#if defined(__NT__) || defined(STRIP_BSLASH)
			      replace(path,"\\","/")
#else
			      path
#endif
			    );
    if( !ss )
      return path[1..];
  }
  return path;
}


string|array(int|string) read( string file,
			       RequestID id,
			       int|void cache,
			       int last_mtime )
//! Read the contents of the specified file, if it exists. If it does
//! not exist, 0 is returned.
//!
//! If @[cache] is specified, the result will be cached. No stat(2)
//! validation is done before returning a value from the cache unless
//! you also specify the @[last_mtime] argument.
//!
//! If last_mtime is specified, ({ mtime, file_contents }) is
//! returned, otherwise only the contents of the file.
{
  Configuration c = id->conf;
  string res, ck;
  int mtime;
  if( cache )
  {
    res = cache_lookup( (ck="files:"+c->name+":"+id->misc->host), file );
    if( res && last_mtime )
    {
      Stat s = stat( file, id );
      if( s && ((mtime=s[ST_MTIME])<=last_mtime) )
	return ({ mtime, res });
      res=0;
    }
  }
  if( !res ) 
    res = c->try_get_file( file, id );
  if( cache )
    cache_set( ck, file, res );
  if( last_mtime && res )
  {
    if( !mtime )
    {
      Stat s = stat( file, id );
      mtime = s && s[ST_MTIME];
    }
    return ({ mtime, res });
  }
  return res;
}

array(string) find_above_read( string above,
			       string name,
			       RequestID id,
			       string|void cache,
			       int|void do_mtime )
//! Operates more or less like a combination of find_above and read. 
//! The major difference from calling read( find_above( above, name,
//! id, cache ), id, cache, last_mtime ) is that this function does
//! automatic mtime handling if you specify do_mtime. Also, it calls
//! find_above repeatedly until it finds a file it can actually read. 
//! This, if there is a file named 'name' in a directory, but it is
//! not readble by the current user, this function will continue
//! looking in the directory above the one in which the file was
//! found.
//!
//! The return value is ({ filename, file-contents, mtime||0 })
//! If no file is found, 0 is returned.
{
#ifdef HTACCESS_DEBUG
  werror("find_above_read(%O, %O, %O, %O, %O)...\n",
         above, name, id, cache, do_mtime);
#endif /* HTACCESS_DEBUG */
  while( strlen( above ) )
  {
    int last_mtime;
    string ck;
    above = find_above( above, name, id, (cache&&cache+":above") );
    if( !above )
      return 0;
    if( do_mtime )
      last_mtime = cache_lookup( (ck=cache+":mtime:"+id->conf->name+
				  ":"+id->misc->host), above )||-1;

    if( string|array data = read( above, id, !!cache, last_mtime ) )
    {
      if( arrayp( data ) )
      {
	cache_set( ck, above, data[0]||-1 );
	return ({ above, data[1], data[0] });
      }
      return ({ above, data, 0 });
    }
    above = combine_path( above, ".." );
  }
  return 0;
}


string find_above( string above,
		   string name,
		   RequestID id,
		   string|void cache )
//! Return the filename of the first file named @[name] _above_ the
//! specified path. As an example, if @[name] is .htaccess, and above
//! is /a/b/c/d/foo.html, this function will search for
//!
//! /a/b/c/d/.htaccess
//! /a/b/c/.htaccess
//! /a/b/.htaccess
//! /a/.htaccess
//! /.htaccess
//!
//! in that order.
//!
//! If @[cache] is specified, the result will be cached under the name
//! specified. No stat(2) validation is done.
{
  string res;
  string ck;
  
  if( above[-1] != '/' )  above = combine_path( above, "../" );

  if( cache )  res = cache_lookup( (ck=cache+":"+
				    id->conf->name+":"+id->misc->host), above );
  if( res )    return res;

  // No luck. Try to locate the file in the VFS.
  array(string) segments = ({""})+(above/"/"-({""}));
  for( int i=sizeof( segments )-1; i>=0 ; i-- )
  {
    string subvpath = combine_path("/"+segments[..i]*"/", name);
    if( Stat st = stat( subvpath, id ) )
    {
      // CONSIDER: Assure that the file can be opened as well?
      res = subvpath;
      break;
    }
  }
  if( res && cache )
    return cache_set( ck, above, res );
  return res;
}
