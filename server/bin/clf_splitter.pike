#!/usr/local/bin/pike

// Reads a Common Log File from standard input and writes (appends)
// output in separate log files named "Log.%y-%m-%d" in current
// directory. Hence, the log data is split into multiple files.

int main()
{
  string data = "";
  
  string fd_filename;
  Stdio.File fd;
  
  while((data += Stdio.stdin.read(4096)) != "")
  {
    array(string) rows = data/"\n";
    foreach(rows[..sizeof(rows)-2], string row)
      if(sscanf(row, "%*s[%d/%s/%d:", int day, string monthname, int year) == 4)
      {
	string filename;
	switch(lower_case(monthname))
	{
	  case "jan": filename = sprintf("%04d-01-%02d", year, day); break;
	  case "feb": filename = sprintf("%04d-02-%02d", year, day); break;
	  case "mar": filename = sprintf("%04d-03-%02d", year, day); break;
	  case "apr": filename = sprintf("%04d-04-%02d", year, day); break;
	  case "may": filename = sprintf("%04d-05-%02d", year, day); break;
	  case "jun": filename = sprintf("%04d-06-%02d", year, day); break;
	  case "jul": filename = sprintf("%04d-07-%02d", year, day); break;
	  case "aug": filename = sprintf("%04d-08-%02d", year, day); break;
	  case "sep": filename = sprintf("%04d-09-%02d", year, day); break;
	  case "oct": filename = sprintf("%04d-10-%02d", year, day); break;
	  case "nov": filename = sprintf("%04d-11-%02d", year, day); break;
	  case "dec": filename = sprintf("%04d-12-%02d", year, day); break;
	  default:
	    error("Unknown month %O\n", monthname);
	}

	if(filename != fd_filename)
	{
	  if(fd)
	    fd->close();
	  fd_filename = filename;
	  fd = Stdio.File("Log." + fd_filename, "acw");
	}

	fd->write(row + "\n");
      }
    data = rows[-1];
  }
  
  if(fd)
    fd->close();
  return 0;
}
