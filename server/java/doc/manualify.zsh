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
mv package-tree.html index.html
rm -f package-*
files=(*.html)
echo "Found $#files files for the manual."

echo -n "Styling some."
replace	'#CCCCFF' '#C1C4DC'
replace	'#EEEEFF' '#DEE2EB'
echo

echo -n "Encasing content."
replace	'</HTML>' '</manual>'
replace	'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">' '<manual>'
echo

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

files=(*.html(:r))
for i in $files
{
  sed 's/<!--.*-->//g;/^$/d' <$i.html >$i.tmp
  mv $i.tmp $i.html
  echo -n '.'
}
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

echo "Cleaning up."
rm -f *\~
mv index.html index.xml

echo "Uploading new javadoc to internal-docs-22.roxen.com..."
lukemftp -u ftp://${USER}@internal-docs-22/roxen/2.2/programmer/java/ *

echo "Please visit http://internal-docs-22/edit/roxen/2.2/programmer/java/ and commit your updates."
