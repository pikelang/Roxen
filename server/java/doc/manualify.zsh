#! /usr/bin/env zsh

function remove ()
{
  rsif "$1" '' $files >/dev/null && echo -n '.'
}

function replace ()
{
  rsif "$1" "$2" $files >/dev/null && echo -n '.'
}

javadoc -nonavbar -sourcepath ../src -d . com.roxen.roxen
cd com/roxen/roxen
files=([A-Z]*.html package-tree.html)
echo "Found $#files files for the manual."
echo -n "Removing cruft."
remove '../../../com/roxen/roxen/'
remove '<LINK REL ="stylesheet" TYPE="text/css" HREF="../../../stylesheet.css" TITLE="Style">'
remove '<!--NewPage-->'
remove '<BODY BGCOLOR="white">'
remove '</BODY>'
remove '<HTML>'
remove '<HEAD>'
remove '</HEAD>'
remove '<HR>'
echo

echo -n "Styling some."
replace	'#CCCCFF' '#C1C4DC'
replace	'#EEEEFF' '#DEE2EB'
echo

echo -n "Encasing content."
replace	'</HTML>' '</manual>'
replace	'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">' '<manual>'
echo

echo -n "Creating menu file."
rm -f sub.menu
for i in [A-Z]*.html(:r)
{
  echo "<mi>" >> sub.menu
  echo "  <title>$i</title>" >> sub.menu
  echo "  <url>$i.html</url>" >> sub.menu
  echo "</mi>" >> sub.menu
  echo -n "."
}
echo

mv package-tree.html index.xml

echo "Cleaning up."
rm -f *\~

echo "Done!"
