#!NO_MODULE
/*
 * by Francesco Chemolli
 * Copyright © 1999 - 2009, Roxen IS.
 *
 * Notice: this might look ugly, it's been designed to fit various kinds of
 * rules-based modules.
 */

constant cvs_version="$Id$";

#include <module.h>
inherit "module";

//override this to allow for more verbose debugging
//include parentheses in the name
string filter_type="FIXME: override filter_type"; 
string rules_doc="FIXME: override rules_doc";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttlelib" \
                                   +filter_type+": "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif


mapping rules;
//format: ([pattern:({command_type,value,0|1(fix)})])
//command_type is a string (+-*/=!), value a float
//if command_type==!, it means no throttling and value is ignored
array(string) rulenames; //needed to keep the rules in order.

//cleans shell-like comments (#..EOL)
string handle_comments(string line) {
  mixed tmp;
  if (sscanf(line,"%*[ \t]%s#%*s",tmp)==3) {
    //comment. Let's trim it out
    line=tmp;
  }
  return String.trim_whites(line); //now the line should be clean.
}

//override this in subclasses to define new configuration line formats
//it takes as input one configuration variable line, and must return either
//an array having in index 0 the configuration key and in index 1 the
//corresponding rule, or a string indicating an error (and in this case
//the string must contain the error code) or 0 if the line doesn't contain
//any configuration info.
array(mixed)|string|int parse_rules_line (string line) {
  int fix=0;
  float val=0;
  string cmd;
  array(string) words;
  line=replace(line,"\t"," ");
  THROTTLING_DEBUG(" examining: '"+line+"'");
  if(!sizeof(line))
    return 0;
  line=handle_comments(line);
  words=(line/" ")-({""}); //({command, modifier, fix?})
  if (sizeof(words)<2 || sizeof(words)>3) {
    return "can't parse";
  }
  if (lower_case(words[1])=="nothrottle") {
    THROTTLING_DEBUG("nothrottle");
    return ({words[0],({"!",0,1})});
  }
  if (sscanf(words[1],"%[-+*/=]%f",cmd,val) != 2) {
    THROTTLING_DEBUG("command not understood");
    return "command not understood";
  }
  if (!((<"+","-","*","/","=","!">)[cmd])) {
    THROTTLING_DEBUG("unknown command");
    return "unknown command";
  }
  if (sizeof(words)>2) {
    if (lower_case(words[2])=="fix") {
      fix=1;
    } else {
       THROTTLING_DEBUG("unknown keyword \""+words[2]+"\"");
       return "uknown keyword ["+words[2]+"]";
    }
  }
  return ({ words[0], ({cmd,val,fix}) });
}

//if there are errors, it will set the rules to a version with the offending
//lines commented out.
//If it returns a string, it's an error message
string|void update_rules(string new_rules) {
  THROTTLING_DEBUG("updating rules");
  mapping my_rules=([]);
  array(string) my_rulenames=({});
  array(string) errors=({}); //contains the lines where parse errors occurred
  string line;
  array(string) lines;

  if (!new_rules || ! sizeof(new_rules)) {
    THROTTLING_DEBUG("new rules empty, returning");
    rules=([]);
    rulenames=({});
    return;
  }
  //  lines=replace(QUERY(rules),"\t"," ")/"\n";
  lines=new_rules/"\n";
  THROTTLING_DEBUG((string)(sizeof(lines))+" lines to examine");
  for (int lineno=0; lineno<sizeof(lines);lineno++) {
    line=lines[lineno];
    mixed got=parse_rules_line(line);
    if (arrayp(got)) { //rule parsed ok.
      my_rules[got[0]]=got[1];
      my_rulenames+=({got[0]});
    }
    if (stringp(got)) { //error
      lines[lineno]="#("+got+") "+lines[lineno];
      errors+=({(string)(lineno+1)});
    }
    //else just let it through.
  }
  if (sizeof(errors)) {
#ifdef IF_ONLY_COULD_CHANGE_RULES
    set("rules",lines*"\n");
#endif
    THROTTLING_DEBUG("Errors in lines "+(errors*", "));
    return "Error"+(sizeof(errors)>1?"s":"") +
      "while parsing line"+(sizeof(errors)>1?"s ":" ")+
      String.implode_nicely(errors)
#ifndef IF_ONLY_COULD_CHANGE_RULES
      +"The errors found are:<br>"
      +lines*"<BR>\n"
#endif
      ;
  }
  THROTTLING_DEBUG(sprintf("rules are:\n%O\n",rules));
  // this guarrantees atomicity in rules setting
  rules=my_rules;
  rulenames=my_rulenames;
}

string|int check_variable(string name, mixed value) {
  mixed err;
  switch (name) {
  case "rules":
    err=update_rules(value);
    if (err) return err;
    return 0;
  }
  return 0;
}

void start() {
  update_rules(QUERY(rules));
}

//looks for a rule, matching the patterns in tomatch.
//If no pattern is found, returns 0
array low_find_rule(string tomatch, array(string) rulenames, mapping rules) {
  THROTTLING_DEBUG("got request for "+tomatch);
  mixed s;
  foreach(rulenames,s) {
    THROTTLING_DEBUG(sprintf("examining %O",s));
    if (glob(s,tomatch)) {
      THROTTLING_DEBUG("!!matched!!");
      return rules[s];
    }
  }
  THROTTLING_DEBUG("!!no match!!");
  return 0;
}

//override this for other rules-based modules.
//it must return a rule array or 0 if no matching rule is found
array find_rule (mapping res, object id, 
                 array(string) rulenames, mapping rules) {
  return 0;
}

void apply_rule(array rule, object id) {
  id->throttle->doit=1;
  switch(rule[0]) {
  case "+": id->throttle->rate+=(int)rule[1];break;
  case "-": id->throttle->rate-=(int)rule[1];break;
  case "*": id->throttle->rate=(int)(id->rate*rule[1]);break;
  case "/": id->throttle->rate=(int)(id->rate/rule[1]);break;
  case "=": id->throttle->rate=(int)rule[1]; break;
  case "!": id->throttle->doit=0; break;
  }
  if (rule[2])
    id->throttle->fixed=1;
}

mixed filter (mapping res, object id) {
  array rule;
  if (id->throttle->fixed)
    return 0;
  rule=find_rule(res,id,rulenames,rules);
  if (!rule)
    return 0;
  apply_rule(rule,id);
}


void create() {
  defvar("rules","","Rules",TYPE_TEXT_FIELD,rules_doc);
}
