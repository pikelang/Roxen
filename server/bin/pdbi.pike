#!/usr/local/bin/pike
/*
 * $Id$
 *
 * name = "PDB Inspector";
 * doc = "This is a tool to inspect PDB databases.";
 */

int rowsize(object o, string table, string row)
{
  return sizeof(encode_value(o[table][row]));
}

int tablesize(object o, string table)
{
  int n = 0;
  foreach(indices(o[table]), string row)
    n += rowsize(o, table, row);
  return n;
}

int du(object o, string|void table, string|void row)
{
  if(row)
    return rowsize(o, table, row);
  if(table)
    return tablesize(o, table);
  
  int n = 0;
  foreach(indices(o), string table)
    n += tablesize(o, table);
  return n;
}

void main(int argc, array argv)
{
  object o = PDB.db(argv[1], "r");
  write("Per Database Inspector\nOK.\n");

  string cmd, table, arg;
  do {
    array a = ((readline("> ") || "exit")/" ") - ({});
    cmd = a[0];
    arg = a[1..]*" ";
    if(!sizeof(arg))
      arg = 0;

    switch(cmd) {
    case "du":
      int n;
      if(table)
	n = du(o, table, arg);
      else
	n = du(o, arg);
      write(sprintf("%d\n", n));
      break;
    case "ls":
      if(table || arg)
	write(indices(o[table || arg])*"\n"+"\n");
      else
	write(indices(o)*"\n"+"\n");
      break;
    case "cat":
      if(table && mkmultiset(indices(o[table]))[arg])
	write(sprintf("%O\n", o[table][arg]));
      else
	write(sprintf("%O: %O: No such row\n", table, arg));
      break;
    case "pwd":
      write("["+(table?table:"")+"]\n");
      break;
    case "cd":
      if(arg == "..") {
	table = 0;
      } else {
	if(mkmultiset(indices(o))[arg])
	  table = arg;
	else
	  write(sprintf("%O: %O: No such table\n", argv[0], arg));
      }
      break;
    case "help":
      write("Available commands are: du, ls, cat, pwd, cd, exit.\n");
      break;
    case "":
    case "exit":
      break;
    default:
      write("nada\n");
    }
  } while(cmd != "exit");    
}
