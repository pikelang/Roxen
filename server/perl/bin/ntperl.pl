# NT Wrapper for Roxen ExtScript perlhelper

if (-f "perlhelper")
  { do "perlhelper";}
elsif (-f "perl/bin/perlhelper")
  { do "perlhelper";}
else
  { exit 1;}

