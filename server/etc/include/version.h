// Version information
// $Id: version.h,v 1.642 2003/02/05 17:53:00 distmaker Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.
constant __roxen_version__ = "3.4";
constant __roxen_build__ = "2";

#if !constant(roxen_release)
constant roxen_release = "-cvs";
#endif /* !constant(roxen_release) */

#ifdef __NT__
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+" NT"+roxen_release;
#else
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+roxen_release;
#endif
