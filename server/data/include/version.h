// Version information
// $Id: version.h,v 1.545 2004/05/31 23:48:17 _cvs_stephen Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.

constant __chilimoon_version__ = "2004";
constant __chilimoon_build__ = "1";

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
