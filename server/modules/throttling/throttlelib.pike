#!NO_MODULE
/*
 * by Francesco Chemolli
 * Copyright © 1999 - 2000, Roxen IS.
 *
 * Notice: this might look ugly, it's been designed to fit various kinds of
 * rules-based modules.
 */

constant cvs_version="$Id: throttlelib.pike,v 1.7 2000/05/15 19:54:18 kinkie Exp $";

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

#define THROW(X) throw( X+"\n" )


mapping rules;
//format: ([pattern:({command_type,value,0|1(fix)})])
//command_type is a string (+-*/=!), value a float
//if command_type==!, it means no throttling
array(string) rulenames; //needed to keep the rules in order.

//if there are errors, it will set the rules to a version with the offending
//lines commented out.
//If it returns a string, it's an error message
string update_rules() {
  THROTTLING_DEBUG("updating rules");
  rules=([]);
  rulenames=({});
#ifndef IF_ONLY_COULD_CHANGE_RULES
  array(string) errors=({}); //contains the lines where parse errors occurred
  int error=0;
#endif
  string line, cmd;
  array(string) lines, words;
  lines=replace(QUERY(rules),"\t"," ")/"\n";
  for (int lineno=0; lineno<sizeof(lines);lineno++) {
    line=lines[lineno];
    THROTTLING_DEBUG(" examining: '"+line+"'");
    int fix=0;
    float val=0;
    string cmd;
    if(!sizeof(line))
      continue;
    if(line[0]=='#')
      continue;
    words=(line/" ")-({""});

    if (sizeof(words)<2) {
      THROTTLING_DEBUG("can't parse");
#ifdef IF_ONLY_COULD_CHANGE_RULES
      lines[lineno]="#(can't parse) "+line;
      error=1;
#else
      errors+=({(string)(lineno+1)});
#endif
      continue;
    }
    
    if (lower_case(words[1])=="nothrottle") {
      THROTTLING_DEBUG("nothrottle");
      cmd="!";
      val=0;
    } else if (sscanf(words[1],"%[-+*/=]%f",cmd,val) != 2) {
      THROTTLING_DEBUG("command not understood");
#ifdef IF_ONLY_COULD_CHANGE_RULES
      lines[lineno]="#(command not understood) "+line;
      error=1;
#else
      errors+=({(string)(lineno+1)});
#endif
      continue;
    }
    if (!((<"+","-","*","/","=","!">)[cmd])) {
      THROTTLING_DEBUG("unknown command");
#ifdef IF_ONLY_COULD_CHANGE_RULES
      lines[lineno]="#(unknown command) "+line;
      error=1;
#else
      errors+=({(string)(lineno+1)});
#endif
      continue;
    }
    if (cmd=="!" || sizeof(words)>2 ) {
      if (cmd=="!" || lower_case(words[2])=="fix")
        //don't change order, or it bangs!
        fix=1;
      else {
        THROTTLING_DEBUG("unknown keyword \""+words[2]+"\"");
#ifdef IF_ONLY_COULD_CHANGE_RULES
        lines[lineno]="#(unknown keyword \""+words[2]+"\") "+line;
        error=1;
#else
        errors+=({(string)(lineno+1)});
#endif
        continue;
      }
    }
    rules[words[0]]=({cmd,val,fix});
    rulenames+=({words[0]});
  }
#ifdef IF_ONLY_COULD_CHANGE_RULES
  if (error) {
    THROTTLING_DEBUG("****ERRORS!****");
    set("rules",lines*"\n");
  }
#else
  if (sizeof(errors)) {
    THROTTLING_DEBUG("Errors in lines "+(errors*", "));
    return "Error"+(sizeof(errors)>1?"s":"") +
      "while parsing line"+(sizeof(errors)>1?"s ":" ")+
      String.implode_nicely(errors);
  }
#endif
  THROTTLING_DEBUG(sprintf("rules are:\n%O\n",rules));
  return 0;
}

string|int check_variable(string name, mixed value) {
  mixed err;
  switch (name) {
  case "rules":
    //    set(name,lower_case(value)); //broken, it will lower_case everything
    err=update_rules();
    if (err) return err;
    return 0;
  }
  return 0;
}

void start() {
  update_rules();
}

//looks for a rule, matching the patterns in tomatch.
//If no pattern is found, returns 0
array low_find_rule(string tomatch, array(string) rulenames, mapping rules) {
  THROTTLING_DEBUG("got request for "+tomatch);
  string s;
  foreach(rulenames,s) {
    THROTTLING_DEBUG("examining "+s);
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
//
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
