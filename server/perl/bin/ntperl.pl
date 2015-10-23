# NT Wrapper for Roxen ExtScript perlhelper

if (-f "perlhelper")
  { do "perlhelper";}
elsif (-f "perl/bin/perlhelper")
  { do "perl/bin/perlhelper";}
else
  { exit 1;}

