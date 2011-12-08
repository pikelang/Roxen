// Version information
// $Id: version.h,v 1.1628 2011/12/08 16:59:31 dist Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.
constant roxen_ver = "5.1";
constant roxen_build = "224";

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
