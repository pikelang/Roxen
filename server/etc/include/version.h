// Version information
// $Id: version.h,v 1.1235 2009/03/11 18:04:56 dist Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.
constant roxen_ver = "5.0";
constant roxen_build = "263";

#if !constant(roxen_release)
constant roxen_release = "-cvs";
#endif /* !constant(roxen_release) */

#ifdef __NT__
constant real_version= "Roxen/"+roxen_ver+"."+roxen_build+" NT"+roxen_release;
#else
constant real_version= "Roxen/"+roxen_ver+"."+roxen_build+roxen_release;
#endif

/* Compat for code that includes this file. (The reason for replacing
 * these two is that pike 7.8 and later reserves all identifiers
 * beginning and ending with "__".) */
#define __roxen_version__ roxen_ver
#define __roxen_build__ roxen_build
