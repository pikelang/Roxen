// Version information
// $Id: version.h,v 1.543 2003/01/14 19:39:59 mani Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.

constant __chilimoon_version__ = "2003";
constant __chilimoon_build__ = "1";

// NGSERVER Remove these
constant __roxen_version__ = __chilimoon_version__;
constant __roxen_build__ = __chilimoon_build__;

#ifdef __NT__
#define NTRELEASE "-NT"
#else
#define NTRELEASE
#endif

#if !constant(chilimoon_release)
constant chilimoon_release = "-cvs" NTRELEASE;
#endif /* !constant(chilimoon_release) */

constant real_version = "ChiliMoon/"+__chilimoon_version__+"."+
  __chilimoon_build__+chilimoon_release;
