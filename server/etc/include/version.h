// Version information
// $Id: version.h,v 1.484 2002/03/25 17:30:38 distmaker Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.
constant __roxen_version__ = "2.4";
constant __roxen_build__ = "53";

#if !constant(roxen_release)
constant roxen_release = "-cvs";
#endif /* !constant(roxen_release) */

#ifdef __NT__
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+" NT"+roxen_release;
#else
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+roxen_release;
#endif
