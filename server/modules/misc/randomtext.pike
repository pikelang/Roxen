// randomtext.pike
//
// Written by Michael Leif Richard Stensson
//
//   PRELIMINARY VERSION! February 1, 2000.
//
//    Roxen module for generating semi-random text based on a set of
//    rules. The functionality is available through a tag
//
//           <make-random-text rules=NAME_OF_RULE_FILE>
//
//    Normally, the module will first look in its cache to see if a
//    random text has recently been generated from the same rules,
//    and if so, return the same result. The optional "nocache"
//    attribute forces a new text to be generated no matter whether
//    one has been cached or not.
//
//    The format of the rule files are a sequence of rules, optionally
//    preceeded by comments. The start of a rule is indicated by a line
//    beginning with three asterisks (***), and alternatives within a
//    rule are separated by lines beginning with three hyphens (---).
//    Rules can have directives specified after a second set of ***,
//    and each alternative (except the first) can have preconditions
//    and postconditions specified after a second set of ---. Within
//    each alternative, actions and inserts can be done using commands
//    quoted with $. For instance:
//
//      // My rule file.
//      ***first-rule
//      anything
//      ---
//      whatever
//
//      ***second-rule***single-shot
//      ONE!
//      ---
//      TWO!
//
//      ***main***trim-spaces
//      $RULE:first-rule$ $RULE:first-rule$
//      ---
//      $RULE:second-rule$ $RULE:second-rule$
//
//    The rules will be invoked through evaluation of the "main" rule.
//    The result of a rule file like the one above will be that we start
//    by invoking either "first-rule" twice, or "second-rule" twice (since
//    these are the alternatives in the "main" rule). The "main" rule
//    has the directive trim-spaces, which indicates that leading and
//    trailing spaces should be removed, and any internal sequences of
//    whitespace should be converted into a single space. The "second-rule"
//    rule has the directive "single-shot", meaning it should only select
//    randomly once, but then produce the same result every time it is
//    called.

#include <module.h>
inherit "module";
inherit "roxenlib";

string version = "$Id: randomtext.pike,v 1.2 2000/02/12 16:09:55 nilsson Exp $";

mapping text_cache = ([ ]);

string recentfile = "(none)", recenterror = "(none)", recentdiag = "(none)";
int    recentsteps, recenttagtime;

void create()
{ defvar("searchpath", "NONE", "Rules File Search Path", TYPE_DIR,
    "This is the location in the real file system where the random "
    "text module will look for rule files.");

  defvar("searchcwd", 0, "Search Document Directory", TYPE_FLAG,
    "If this option is enabled, the module will search the current "
    "directory for rule files before trying the general rules file "
    "search path. (Note: may not work yet.)");

  defvar("flushcache", 3, "Minutes Between Cache Flushes", TYPE_MULTIPLE_INT,
    "This is the number of minutes that should pass between each "
    "flushing of the text cache. The default value for this option "
    "is 3.",
         ({ 0, 1, 2, 3, 5, 10, 15 })
        );
}

constant module_type = MODULE_PARSER;
constant module_name = "Random Text Generator Module";
constant module_doc  = "This module provides a simple way of generating texts on a "
  "semi-random basis according to a set of rules. Apart from its "
  "amusement value, this can be useful for testing and educational "
  "purposes, such as generating small quiz pages or producing "
  "many different kinds of input to text processing tags.";

string status()
{ return
     "<b>Most recent tagtime</b>:" + recenttagtime + "<br>" +
     "<b>Most recent file</b>:" + recentfile + "<br>" +
     "<b>Most recent error</b>:" + recenterror + "<br>" +
     "<b>Steps in recent run</b>:" + recentsteps + "<br>" +
     "<b>Debug diagnostics</b>:" + recentdiag + "<br>" +
     "<b>Text cache for</b>: " + sprintf("%O", indices(text_cache));
}

void flush_cache()
{ int period = 60*query("flushcache");
  text_cache = ([ ]);
  call_out(flush_cache, period < 5 ? 5 : period);
}

void start()
{ int period = 60*query("flushcache");
  call_out(flush_cache, period < 5 ? 5 : period);
}

string rtt_parse(mapping sections, string sec, mapping args, int depth)
{ int choice, counts;

  if (!mappingp(sections[sec]))
      return "<p><h2>Error: no '" + sec + "' rule</h2>";

  if (depth > 30)
      return "<p><h2>Error: too deep recursion</h2>";

  if (sections[sec]["single-shot"] && sections[sec]["result"])
      return sections[sec]["result"];

  if (sections["steps"]++ > 10000)
      return "<h2>Error: too long evaluation</h2>";

#ifdef DEBUG
  recentdiag += sprintf("[%s:: %O]", sec, args);
#endif

  choice = -1; counts = 0;

  while (choice < 0)
  { choice = random(1+sections[sec]["index"]);

    if (choice == sections[sec]["lastindex"] &&
        sections[sec]["avoid-repeat"] == 1)
      choice = (choice+1) % (1+sections[sec]["index"]);

    array conds = sections[sec]["conditions"+choice];

    if (conds == 0) conds = ({ });

#ifdef DEBUG
    recentdiag += "Choice: " + choice + ".";
#endif

    foreach(conds, string precond)
    { // recentdiag += "Cond '" + precond + "'.";
      if (stringp(precond) && precond != "")
      { if (precond[0..0] == "!")
          { if (args[upper_case(precond[1..])])
              choice = -1;
#ifdef DEBUG
            recentdiag += "(N:" + args[upper_case(precond[1..])] + ") ";
#endif
          }
        else if (sizeof(precond / "!=") == 2)
          { if (args[upper_case((precond/"!=")[0])] == args[(precond/"!=")[1]])
              choice = -1;
          }
        else if (sizeof(precond / "==") == 2)
          { if (args[upper_case((precond/"!=")[0])] == args[(precond/"==")[1]])
              choice = -1;
          }
        else if (args[upper_case(precond)])
           { choice = -1;
#ifdef DEBUG
             recentdiag += "/";
#endif
           }
        else
           {
#ifdef DEBUG
             recentdiag += "(?)";
#endif
           }
      }
#ifdef DEBUG
      if (choice == -1) recentdiag += "(!F)";
#endif
    }

    if (++counts > 7 && choice == -1)
    { choice = 0;
#ifdef DEBUG
      recentdiag += "Break: choice=0.";
#endif
      break;
    }
  }

  sections[sec]["lastindex"] = choice;

  array actions = sections[sec]["actions"+choice];
  if (actions == 0) actions = ({ });

  foreach(actions, string action)
  { // recentdiag += "Action '" + action + "'";
    if (sizeof(action / "=") == 2)
       { args[upper_case((action / "=")[0])] = (action / "=")[1];
         // recentdiag += " (SET!)";
       }
    else
       recenterror = "Bad action in rule '" + sec + "'";
  }

  string text = sections[sec][choice];

  if (sizeof(text / "$") > 2)
  { array a = text / "$"; string assignvar = 0; int i;
    for(i = 1; i < sizeof(a); i += 2)
    { if (a[i][0..3] == "SET:" || a[i][0..6] == "ASSIGN:")
      { array elts = a[i] / ":";
        if (sizeof(elts) > 2)
        { assignvar = upper_case(elts[1]);
          a[i] = elts[2..] * ":";
        }
        else { assignvar = "-";}
      }
      else assignvar = 0;

      if (a[i][0..4] == "RULE:")
          a[i] = rtt_parse(sections, lower_case(a[i][5..]), args, depth+1);
      else if (a[i][0..8] == "VARIABLE:")
          a[i] = args[upper_case(a[i][9..])];
      else if (a[i][0..6] == "SELECT:")
        { array b = a[i][7..] / "|";
          a[i] = b[random(sizeof(b))];
        }
      else if (a[i][0..6] == "STRING:")
        { a[i] = a[i][7..];
        }
      else if (a[i] == "GLUE"  || a[i] == "NEWLINE" ||
               a[i] == "SPACE" || a[i] == "CAPITALIZE")
          a[i] = "<<<" + a[i] + ">>>";
      else
          a[i] = "<b>(?" + a[i] + "?)</b>";

      if (assignvar)
      { args[assignvar] = a[i];
        a[i] = ""; /* Old debug code: "{" + assignvar + ": " + a[i] + "}"; */
      }
    }
    text = a * "";
  }

  int zap;

  if (sections[sec]["trim-spaces"])
  { while ((zap = search(text, "\n")) >= 0)
       text = (zap > 0 ? text[0..zap-1] : "") + " " + text[zap+1..];
    while (sizeof(text) > 0 && text[ 0.. 0] == " ") text = text[1..];
    while (sizeof(text) > 0 && text[-1..-1] == " ") text = text[0..-2];
    while ((zap = search(text, "  ")) >= 0)
      { text = text[0..zap] + text[zap+2..];}
  }

  while ((zap = search(text, "<<<GLUE>>>")) >= 0)
  { int pre, post;
    for(pre = zap-1;
        pre >= 0 && (< "\n", " " >)[text[pre..pre]];
        --pre);
    for(post = zap+10;
        post < sizeof(text) && (< "\n", " " >)[text[post..post]];
        ++post);
    text = (pre >= 0 ? text[0..pre] : "") + text[post..];
  }

  while ((zap = search(text, "<<<SPACE>>>")) >= 0)
    text = (zap > 0 ? text[0..zap-1] : "") + " " + text[zap+11..];

  while ((zap = search(text, "<<<NEWLINE>>>")) >= 0)
    text = (zap > 0 ? text[0..zap-1] : "") + "\n" + text[zap+12..];

  while ((zap = search(text, "<<<CAPITALIZE>>>")) >= 0)
  { string t1 = (zap > 0 ? text[0..zap-1] : "");
    string t2 = text[zap+16..];
    if (t2[0..0] == " " || t2[0..0] == "\n") { t1 += t2[0..0]; t2 = t2[1..];}
    text = t1 + String.capitalize(t2);
  }

  if (sections[sec]["assign"])
     args[sections[sec]["assign"]] = text;

  if (sections[sec]["single-shot"])
     sections[sec]["result"] = text;

  return text;
}

string rtt_read(string path)
{ int lineno = 0; string line, mode = 0, tmp;
  mapping sections = ([ "steps": 0 ]);
  string this_section = "***";
  int secindex = -1;

  if (Stdio.file_size(path) < 0)
     return "<h2>error: unable to access rule file</h2>";

  object f = Stdio.FILE(path, "r");
  if (!f) return "<b>Error: no rule file found for '" + path + "'</b>";

  recentfile = path;

  while (line = f->gets())
  { ++lineno;
    if (line[0..2] == "***")
    { array a = line / "***";
      array b = a[1] / " ";
      recentdiag = sprintf("%O", b);
      this_section = lower_case(b[0]);
      sections[this_section] = ([ "index" : 0, "lineno": lineno, 0: "" ]);
      if (sizeof(a) > 2 && stringp(a[2]))
        foreach((a[2] / " "), string option)
        { if (option[0..6] == "assign:")
            { sections[this_section]["assign"] = option[7..];}
          else if (option == "trim-spaces" || option == "single-shot")
            { sections[this_section][option] = 1;}
          else if (option == "avoid-repeat")
            { sections[this_section]["avoid-repeat"] =  1;
              sections[this_section]["lastindex"]    = -1;
            }
        }
      secindex = 0;
    }
    else if (line[0..2] == "---")
    { array a = line / "---";
      sections[this_section]["index"] = ++secindex;
      sections[this_section][secindex] = "";
      if (sizeof(a) > 1)
         sections[this_section]["conditions"+secindex] = a[1] / " ";
      if (sizeof(a) > 2)
         sections[this_section]["actions"+secindex] = a[2] / " ";
    }
    else if (line[0..2] == "///")
    { ; 
    }
    else
    { if (secindex >= 0 && secindex < 20)
        if (line != "")
          sections[this_section][secindex] += line + "\n";
    }
  }

  string result = rtt_parse(sections, "main", ([ ]), 0);
  recentsteps = sections["steps"];

  return result;
}

mixed make_random_text(string tag, mapping attr, object id)
{ recenttagtime = time();
  if (attr->rules)
  { string path = attr->rules;
    if (!path || !stringp(path))
           path = "default";
    if (sizeof(path / "/") > 1)
           return "<b>make-random-text: `/' not allowed in rules name</b>";
    path = query("searchpath")+"/"+path;
    if (Stdio.file_size(path) < 0 && Stdio.file_size(path + ".rtt") > 0)
           path += ".rtt";
    if (Stdio.file_size(path) > 0)
    { if (attr->nocache)
         return rtt_read(path);
      if (!text_cache[path])
         text_cache[path] = rtt_read(path);
      return text_cache[path];
    }
    return "<b>make-random-text: `" + (attr->rules) + "' rules not found</b>";
  }
  return "<b>make-random-text: no `rules' attribute</b>";
}

mapping query_tag_callers()
{ return ([ "make-random-text" : make_random_text ]);
}



