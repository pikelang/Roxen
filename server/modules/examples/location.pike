// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

#include <module.h>
inherit "module";
// All roxen modules must inherit module.pike

constant cvs_version = "$Id$";
constant module_type = MODULE_LOCATION;
constant module_name = "RefDoc for MODULE_LOCATION";
constant module_doc = "This module does nothing, but its inlined "
		      "documentation gets imported into the roxen "
		      "programmer manual. You really don't want to "
		      "add this module to your virtual server, promise!";

// see common_api.pike for further explanations of the above constants

void create()
{
  defvar("mountpoint",
	 Variable.Location("/dev/urandom/sort/of/", 0,
			   "Mount point",
			   "This is where the module will be inserted "
			   "in the namespace of your server."));
}

mapping|Stdio.File|void find_file( string path, RequestID id )
//! The return value is either a <ref>result mapping</ref>, an
//! open file descriptor or 0, signifying that your module did not
//! handle the request.
//!
//! This is the fundamental method of all location modules and is, as
//! such, required. It will be called to handle all accesses below the
//! module's mount point. The path argument contains the path to the
//! resource, in the module's own name space, and the id argument
//! contains the request information object.
//!
//! That the path is in the modules name space means that the path
//! will only contain the part of the URL after the module's mount
//! point. If a module is mounted on <tt>/here/</tt> and a user
//! requests <tt>/here/it/is.jpg</tt>, the module will be called with
//! a path of <tt>it/is.jpg</tt>. That way, the administrator can set
//! the mount point to anything she wants, and the module will keep
//! working. Note that changing the mount point to <tt>/here</tt>
//! would give the module the path <tt>/it/is.jpg</tt> for that
//! request.
//!
//! A zero return value means that the module could not find the
//! requested resource. In that case roxen will move on and try to
//! find the resource in in other location modules. Returning -1 means
//! that the requested resource is a directory, in which case the
//! request will be handled by a directory type module.
//!
//! If the module could handle the request, the return value is either
//! a <ref>response mapping</ref> or a Stdio.File object containing
//! the requested file.
{
  return Roxen.http_string_answer(make_random_string( 17, 17 ));
}

string make_random_string(int min_len, int|void max_len)
{
  int length = min_len + (max_len ? random(max_len - min_len)
				  : random(17));
  return (string)allocate(length, lambda(){ return random(256); })();
}

string query_location()
//! Returns the location in the virtual server's where your location
//! module is mounted. If you make a location module and leave out
//! this method, the default behaviour inherited from module.pike
//! will return the value of the module variable 'location'.
{
  return query( "mountpoint" );
}

array(int)|Stat stat_file( string path, RequestID id )
//! The stat_file() method emulates Pike's <pi>file_stat()</pi>
//! method, returning information about a file or directory. path
//! is the path to the file or directory in the module's name space,
//! id is the request information object.
//!
//! stat_file() is most commonly used by directory type modules to
//! provide informative directory listings, or by the ftp protocol
//! module to create directory listings.
//!
//! The return value it is expected to be either a Stat object, or an
//! array of integers in the following format:
//!
//! ({ mode, size, atime, mtime, ctime, uid, gid })
//!
//! <tt>mode</tt> is an integer containing the unix file permissions
//! of the file. It can be ignored.
//!
//! <tt>size</tt> is an integer containing the size of the file, or a
//! special value in case the object is not actually a file. Minus two
//! means that it is a directory, minus three that it is a symbolic
//! link and minus four that it is a device special file. This value
//! must be given.
//!
//! <tt>atime</tt> is a unixtime integer containing the last time the
//! file was accessed (seconds since 1970). It can be ignored.
//!
//! <tt>mtime</tt> is a unixtime integer containing the last time the
//! file was modified (seconds since 1970). It will be used to handle
//! Last-Modified-Since requests and should be supplied if possible.
//!
//! <tt>ctime</tt> is a unixtime integer containing the time the file
//! was created (seconds since 1970). It can be ignored.
//!
//! <tt>uid</tt> is an integer containing the user id of this file. It
//! will be correlated with the information from the current
//! authentication type module, and used by the CGI executable
//! support module to start CGI scripts as the correct user. It is
//! only necessary for location modules that provide access to a real
//! file system and that implement the <ref>real_file()</ref> method.
//!
//! <tt>gid</tt> is an integer containing the group id of the file. It
//! is needed when uid is needed.
{
  return ({ 0775, // mode
	    ({ 17, -2 })[random(2)], // size/special
	    963331858, // atime
	    963331858, // mtime
	    963331858, // ctime
	    0, // uid
	    0 /* gid */ });
} // Of course, it's typically silly to return something like this.

mapping(string:array(int)|Stat) find_dir_stat( string path, RequestID id );
//! Need not be implemented. The parameter `path' is the path to a
//! directory, `id' is the request information object and the returned
//! mapping contains all filenames in the directory mapped to Stat
//! objects (or arrays for pike 7.0) for the same files respectively.
//!
//! If this method is not implemented, the find_dir_stat function
//! inherited from <tt>module.pike</tt> maps the result of
//! <ref>find_dir()</ref> over <ref>stat_file()</ref> to produce the
//! same result. Providing your own find_dir_stat might be useful if
//! your module maps its files from a database, in which case you
//! would gain performance by using just one big query instead of
//! hordes of single-file queries.

string|void real_file( string path, RequestID id );
//! This method translates the path of a file in the module's name
//! space to the path to the file in the real file system. path
//! is the path to the file in the module's name space, id is the
//! request information object.
//!
//! If the file could not be found, or the file doesn't exist on a
//! real file system, zero should be returned. Only location modules
//! that access server files from a real file system need implement
//! this method. See also the <ref>stat_file()</ref> method.

array(string)|void find_dir( string path, RequestID id )
//! The find_dir() returns a directory listing; an array of strings
//! containing the names of all files and directories in this
//! directory. The path parameter is the path to the directory, in the
//! module's name space, id is the request information object.
//!
//! This method is usually called because a previous call to
//! find_file() returned that this path contained a directory and a
//! directory type module is right now trying to create a directory
//! listing of this directory. Note that it is possible that the
//! find_dir() is called in several location modules, and that the
//! actual directory listing shown to the user will be the
//! concatenated result of all those calls.
//!
//! To find information about each entry in the returned array the
//! <ref>stat_file()</ref> is used.
{
  return allocate(random(47)+11, make_random_string)(4, 71);
}
