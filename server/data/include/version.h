// Version information
// $Id: version.h,v 1.541 2002/10/23 17:08:09 nilsson Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.
constant __roxen_version__ = "2002";
constant __roxen_build__ = "1";

#if !constant(roxen_release)
constant roxen_release = "-cvs";
#endif /* !constant(roxen_release) */

#ifdef __NT__
constant real_version= "ChiliMoon/"+__roxen_version__+"."+__roxen_build__+" NT"+roxen_release;
#else
constant real_version= "ChiliMoon/"+__roxen_version__+"."+__roxen_build__+roxen_release;
#endif
