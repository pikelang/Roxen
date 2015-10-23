// This script removes all files listed in .distignore-files as well
// as the .distignore-files themselves.
//
// Copyright © 2000 - 2009, Roxen IS.

void my_rm(string path) {
  if( Stdio.recursive_rm(path) )
    werror("Removed %s\n", path);
  else
    werror("Could no remove %s\n", path);
}


void clean(string path) {
  array globs = ({});
  if(file_stat(path+".distignore")) {
    string ignore = Stdio.read_file(path+".distignore");
    globs = map(ignore/"\n",
		lambda(string in) {
		  if(sizeof(in) && in[0]=='#')
		    in="";
		  return String.trim_whites(in);
		}) - ({""});
    my_rm(path+".distignore");
  }
  foreach(get_dir(path), string file) {
    foreach(globs, string g)
      if( glob(g, file) )
	my_rm(path+file);
    Stdio.Stat s = file_stat(path+file);
    if(s && s[1]==-2)
      clean(path+file+"/");
  }
}

void main() {
  if(!has_value(get_dir("."), "server"))
    error("Distclean must be run with the installation root as pwd.\n");
  clean( "./" );
}
