// This is a ChiliMoon module. Copyright © 2002-2003 The Caudium Group
/*
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */
/*
 * $Id: calendar.pike,v 1.1 2004/07/17 09:53:46 _cvs_dirix Exp $
 */
/*
 * TODO: JS and CSS docs (yuck!)
 */
constant cvs_version="$Id: calendar.pike,v 1.1 2004/07/17 09:53:46 _cvs_dirix Exp $";
constant thread_safe=1;
#include <module.h>

inherit "module";
inherit "roxenlib";

constant module_type = MODULE_PARSER;
constant module_name = "Calendar tag";
constant module_doc  = #"<div style=\"margin: 15pt\">The calendar tag produces a calendar \"control\" with the year, month, day and week navigation. The tag allows the site designer to define the ranges of years in which the control should operate. Calendar works both for the imperial calendar (week starting Sunday) and for the European on (week starting MOnday). The designer can specify <em>hot dates</em> - that is days/weeks which can be clicked by the user. Every hot date can have an associated <em>action handler</em> defined in a separate tag. Each action handler can handle a range and/or a selection of dates. In addition, you can define your own CSS stylesheet or use the default one, use the default JavaScript handlers of the form from which the calendar is constructed or define your own routines.
The module defines the following tags:</div><p></p>
<style type=\"text/css\">
table.tags { border-width: thin; border-color: #000000; border-style: solid; font-size: small; width: 90%;}
td.first { border-style: solid dotted none none; border-width: thin; border-color: #000000; padding-left: 15pt; font-family: monospace; }
td.normal { border-style: solid dotted none none; border-width: thin; border-color: #000000; padding-left: 3pt; }
td.last { border-style: solid none none none; border-width: thin; border-color: #000000; padding-left: 3pt; }
td.tag { background: #ececec; font-weight: bold; }
td.note { background: #cecece; font-weight: bold; font-family: monospace; text-align: center;}
</style>
<div style=\"padding-top: 10pt; padding-bottom: 10pt; margin: 15pt;\">
<ul>
<li><strong>&lt;calendar&gt;</strong> - the main container in which you can define the hot dates.</li>
<li><strong>&lt;hotdate&gt;</strong> - tag to define a hot (clickable) date. Works only within the &lt;calendar&gt; container.</li>
<li><strong>&lt;startdate&gt;</strong> - the date to which the calendar should be set when first accessed. Works only within the &lt;calendar&gt; container.</li>
<li><strong>&lt;calendar_action&gt;</strong> or <strong>&lt;calendar-action&gt;</strong> - defines handler code for one or more of the defined hot dates.</li>
<li><strong>&lt;calendar_js&gt;</strong> or <strong>&lt;calendar-js&gt;</strong> - outputs the default JavaScript code for the calendar form. Should be put in the &lt;head&gt; container.</li>
<li><strong>&lt;calendar_css&gt;</strong> or <strong>&lt;calendar-css&gt;</strong> - outputs the default CSS code for the calendar form. Should be put in the &lt;head&gt; container.</li>
</ul>
</div>
<div style=\"margin: 15pt\">
<strong>Ranges</strong>. All of the tags and containers can take ranges of numbers as their arguments to specify desired span of days/dates to handle. Ranges follow a very simple syntax - they are a list of comma separated numbers or ranges of numbers separated with a dash. For example <tt>1,2,3,4-10</tt> defines a range consisting of the numbers 1 2 3 and from 4 through 10.
</div>
<div style=\"margin: 15pt\">
Syntax of all the tags follows.
<table class=\"tags\" cellspacing=\"0\" cellpadding=\"0\" align=\"center\">
<tr><td colspan=\"3\" class=\"tag\">calendar</td></tr>
<tr><th>Attribute</th><th>Description</th><th>Default value</th></tr>
<tr><td class=\"first\">do_week</td><td class=\"normal\">If set, then the calendar will contain the week column.</td><td class=\"last\">not set</td></tr>
<tr><td class=\"first\">ds_formname</td><td class=\"normal\">The date selector form name</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">ds_monthclass</td><td class=\"normal\">CSS class name for the month selector</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">ds_yearclass</td><td class=\"normal\">CSS class name for the year selector</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">lang</td><td class=\"normal\">Set the language to be used for the month and weekday names. If this attribute is not set, the value is read from the request variable with the same name.</td><td class=\"last\">not set</td></tr>
<tr><td class=\"first\">md_cellclass</td><td class=\"normal\">CSS class name of a single cell in the monthdays grid.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">md_errorclass</td><td class=\"normal\">CSS class name of the row for error messages.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">md_rowclass</td><td class=\"normal\">CSS class name of a single row in the monthdays grid.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">md_textcellclass</td><td class=\"normal\">CSS class name of the textual contents of a single cell.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">md_todaytextcellclass</td><td class=\"normal\">CSS class name of the textual contents of the cell representing the current day.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">md_todaycellclass</td><td class=\"normal\">CSS class name of the cell representing the current day.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">md_weekclass</td><td class=\"normal\">CSS class name of a single week column cell.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">mt_width</td><td class=\"normal\">The bounding (main) table width.</td><td class=\"last\">200</td></tr>
<tr><td class=\"first\">mt_cellspacing</td><td class=\"normal\">The bounding table cell spacing.</td><td class=\"last\">1</td></tr>
<tr><td class=\"first\">mt_cellpadding</td><td class=\"normal\">The bounding table cell padding.</td><td class=\"last\">1</td></tr>
<tr><td class=\"first\">mt_bgcolor</td><td class=\"normal\">The bounding table background color.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">mt_class</td><td class=\"normal\">The bounding table CSS class name.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">nocss</td><td class=\"normal\">Whether to skip generating CSS attributes.</td><td class=\"last\">not set</td></tr>
<tr><td class=\"first\">wd_cellclass</td><td class=\"normal\">The weekdays cell CSS class name.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">wdc_width</td><td class=\"normal\">The weekdays cell width.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">wdr_bgcolor</td><td class=\"normal\">The weekdays row background color.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">wd_rowclass</td><td class=\"normal\">The weekdays row CSS class name.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">wd_sundayclass</td><td class=\"normal\">The Sunday cell CSS class name.</td><td class=\"last\">in CIF</td></tr>
<tr><td class=\"first\">weekstart</td><td class=\"normal\"><tt>s</tt> for Sunday, anything else for Monday.</td><td class=\"last\">Monday</td></tr>
<tr><td class=\"first\">years</td><td class=\"normal\">A range of years this calendar will use.</td><td class=\"last\">current year</td></tr>

<tr><td colspan=\"3\" class=\"tag\">hotdate</td></tr>
<tr><th>Attribute</th><th>Description</th><th>Default value</th></tr>
<tr><td class=\"first\">after</td><td class=\"normal\">Specifies that days after the specified point in time should be marked active. Acceptable values are <tt>tomorrow</tt>, <tt>today</tt>, <tt>yesterday</tt> or <tt>specified</tt>. The latter value means that you have to pass additional attributes to set the starting point.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">before</td><td class=\"normal\">Same as for the <tt>after</tt> attribute, but all days earlier than the specified point of time are marked.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">day</td><td class=\"normal\">When <tt>before</tt> or <tt>after</tt> have been used with the <em>specified</em> value, sets the day for the starting date. If <tt>before</tt> and <tt>after</tt> are absent, sets the specific day as the active one.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">month</td><td class=\"normal\">Same as <tt>day</tt>. Sets the month of the start date.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">year</td><td class=\"normal\">Same as <tt>day</tt>. Sets the year of the start date.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">week</td><td class=\"normal\"> Sets the active week. Ignored for <tt>before</tt> and <tt>after</tt></td><td class=\"last\"></td></tr>

<tr><td colspan=\"3\" class=\"tag\">startdate</td></tr>
<tr><th>Attribute</th><th>Description</th><th>Default value</th></tr>
<tr><td class=\"first\">today</td><td class=\"normal\">If present, then the calendar start date will be today (server time). This is also the default if no attributes are passed to this tag. Takes no value.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">tomorrow</td><td class=\"normal\">The calendar will start set to the tomorrow's date (server time). Takes no value.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">yesterday</td><td class=\"normal\">The calendar will start set to the yesterday's date (server time). Takes no value.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">day</td><td class=\"normal\">Calendar will start set to this day.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">month</td><td class=\"normal\">Calendar will start set to this month.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">year</td><td class=\"normal\">Calendar will start set to this year.</td><td class=\"last\">none</td></tr>

<tr><td colspan=\"3\" class=\"tag\">calendar_action or calendar-action</td></tr>
<tr><th>Attribute</th><th>Description</th><th>Default value</th></tr>
<tr><td class=\"first\">default</td><td class=\"normal\">Marks this handler as the default one. Such handler is always executed, no matter whether there are any other handlers for some hot date. If the tag is passed no attributes, this is the default behavior.</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">day</td><td class=\"normal\">Handler will react to this day (or days if a range is used).</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">month</td><td class=\"normal\">Handler will react to this month (or months if a range is used).</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">year</td><td class=\"normal\">Handler will react to this year (or years if a range is used).</td><td class=\"last\">none</td></tr>
<tr><td class=\"first\">week</td><td class=\"normal\">Handler will react to this week (or weeks if a range is used).</td><td class=\"last\">none</td></tr>
<tr><td class=\"note\" colspan=\"3\">If at least two attributes of <tt>day</tt>, <tt>month</tt> and <tt>year</tt> are specified together then the handler will respond only to selection that fits all the criteria. Week ranges are always handled independently to the other values.</td></tr>

<tr><td colspan=\"3\" class=\"tag\">calendar_js or calendar-js</td></tr>
<tr><td class=\"note\" colspan=\"3\">This tag takes no attributes.</td></tr>

<tr><td colspan=\"3\" class=\"tag\">calendar_css or calendar-css</td></tr>
<tr><td class=\"note\" colspan=\"3\">This tag takes no attributes.</td></tr>
</table>
</div>
";
constant module_unique = 1;

// fallback for the month names
private array(string) en_months = ({
  "January", "February", "March", "April", "May",
  "June", "July", "August", "September", "October",
  "November", "December"
});

private string en_days = "MTWTFSS";

void create()
{
  defvar("mt_bgcolor", "#6699CC", "Colors: Main table background", TYPE_STRING,
         "Color of the main table background");
  defvar("ds_bgcolor", "#6699CC", "Colors: Date selector background", TYPE_STRING,
         "Color of the date selector background");
  defvar("wdr_bgcolor", "#6699CC", "Colors: Weekdays row background", TYPE_STRING,
         "Color of the weekdays row background");

  defvar("mt_class", "cal-main", "CSS Classes: Main table", TYPE_STRING,
         "Main table CSS class name");
  defvar("ds_monthclass", "cal-month", "CSS Classes: Month selector", TYPE_STRING,
         "Month selector CSS class name.");
  defvar("ds_yearclass", "cal-year", "CSS Classes: Year selector", TYPE_STRING,
         "Year selector CSS class name.");
  defvar("wd_rowclass", "cal-days", "CSS Classes: Weekdays row", TYPE_STRING,
         "Weekdays row CSS class name.");
  defvar("wd_cellclass", "cal-td", "CSS Classes: Weekdays cell", TYPE_STRING,
         "Weekdays cell CSS class name.");
  defvar("wd_sundayclass", "cal-tdsunday", "CSS Classes: Weekdays Sunday cell", TYPE_STRING,
         "Weekdays Sunday cell CSS class name.");
  defvar("md_rowclass", "cal-row", "CSS Classes: Month days row", TYPE_STRING,
         "Month days row CSS class name.");
  defvar("md_cellclass", "cal-td", "CSS Classes: Month days cell", TYPE_STRING,
         "Month days cell CSS class name.");
  defvar("md_todaycellclass", "cal-today", "CSS Classes: Month days 'today' cell", TYPE_STRING,
         "Month days 'today' cell CSS class name.");
  defvar("md_textclass", "cal-text", "CSS Classes: Month days cell text", TYPE_STRING,
         "Month days cell text CSS class name.");
  defvar("md_todaytextclass", "cal-todaytext", "CSS Classes: Month days 'today' cell text", TYPE_STRING,
         "Month days 'today' cell text CSS class name.");
  defvar("md_errorclass", "cal-error", "CSS Classes: Invalid date", TYPE_STRING,
         "CSS class name for the 'Invalid date' message cell.");
  defvar("md_weekclass", "cal-weekdata", "CSS Classes: Week number cell", TYPE_STRING,
         "CSS class name for week number cell.");
    
  defvar("ds_formname", "calendarform", "Names: Calendar form name", TYPE_STRING,
         "Name of the form element that contains the date selector.");
    
  defvar("js_month", "disp_month", "JavaScript: Month change function", TYPE_STRING,
         "Name of the function that will handle the month change.");
  defvar("js_year", "disp_year", "JavaScript: Year change function", TYPE_STRING,
         "Name of the function that will handle the year change.");
  defvar("js_day", "disp_day", "JavaScript: Day change function", TYPE_STRING,
         "Name of the function that will handle the day change.");
  defvar("js_week", "disp_week", "JavaScript: Week click function", TYPE_STRING,
         "Name of the function that will handle the week click.");
  
  defvar("wdc_width", "14", "Dimensions: Width of the calendar cells", TYPE_STRING,
         "Width of a single cell in the calendar grid. In percent.");
}

void start(int level, object _conf)
{}

static array(object) make_years(object id, string yr, object now, object target)
{
  if (!yr || !sizeof(yr))
    return now->years();
    
  array(string)  parts = yr / ",";
  array(object)  ret = ({});
    
  foreach(parts, string part) {
    int   yr_start, yr_end;

    switch(sscanf(part, "%d-%d", yr_start, yr_end)) {
        case 2:
          if (yr_end < yr_start) {
            yr_end ^= yr_start;
            yr_start ^= yr_end;
            yr_end ^= yr_start;
          }
          break;

        case 1:
          yr_end = -1;
          break;

        default:
          yr_end = yr_start = -1;
          break;
    }

    if (yr_start < 0 && yr_end < 0)
      continue;
    else if (yr_end < 0)
      ret += Calendar.Year(yr_start)->years();
    else
      ret += Calendar.Year(yr_start - 1)->range(Calendar.Year(yr_end - 1))->years();
  }

  return sizeof(ret) ? ret : now->years();
}

static string make_ds_form(object id, mapping my_args, object now, object target)
{
  mapping ds_form = ([]);
  mapping ds_month = ([]);
  mapping ds_year = ([]);
  mapping ds_table = ([
    "align" : "center",
    "width" : "100%",
    "border" : "0"
  ]);
  mapping ds_changetype = ([
    "type" : "hidden",
    "name" : "changetype",
    "value" : "unknown"
  ]);
    
  string  tcontents = "<tr><td align='center' nowrap='yes'>";
  string  fcontents = "";
  string  mcontents = "";
  string  ycontents = "";
    
  ds_form->name = my_args->ds_formname || QUERY(ds_formname);
  ds_form->method = "POST";
  ds_form->action = "";
    
  ds_month->name = "month";
  ds_month->onChange = QUERY(js_month) + "()";
  ds_month->size = "1";
  if (!my_args->nocss)
    ds_month->class = my_args->ds_monthclass || QUERY(ds_monthclass);
  ds_month->scrolling = "no";

  ds_year->name = "year";
  ds_year->onChange = QUERY(js_year) + "()";
  if (!my_args->nocss)
    ds_year->class = my_args->ds_yearclass || QUERY(ds_yearclass);
  ds_year->size = "1";
    
  ds_table->width = "100%";
  ds_table->align = "center";
  ds_table->border = "0";
    
  // generate the month names
  function      month_names = core->language(my_args->lang || id->variables->lang || 0, "month");
  array(string) months;
  int           mnum = 1;
  int           month_no = (int)id->variables->calmonth;
  int           Now = (int)id->variables->calyear;
    
  if (!month_names)
    months = en_months;
  else {
    months = ({});
    for (;mnum <= 12; mnum++)
      months += ({ month_names(mnum) });
    mnum = 1;
  }

  foreach(months, string month) {
    mcontents += sprintf("<option value='%02d'%s>%s</option>",
                         mnum++, (mnum - 1 == month_no ? " selected='yes'" : ""), month);
  }
    
  string years_range;
    
  if (!my_args->years || !sizeof(my_args->years)) {
    object c = now->year_no();
        
    years_range = sprintf("%d-%d", c - 1, c + 1);
  } else
    years_range = my_args->years;

  array(object) years = make_years(id, years_range, now, target);
  multiset(int) valid_years = (<>);
    
  foreach(years, object year) {
    int           year_no = year->year_no();

    valid_years += (<year_no>);
    ycontents += sprintf("<option value='%4d'%s>%4d</option>",
                         year_no, (Now == year_no ? " selected='yes'" : ""), year_no);
  }

  if (!valid_years[(int)id->variables->calyear])
    id->misc->_calendar->year_invalid = 1;
  else
    id->misc->_calendar->year_invalid = 0;
    
  mapping input = ([
    "type" : "hidden",
  ]);
    
  fcontents = make_container("select", ds_month, mcontents) + make_container("select", ds_year, ycontents);
    
  input->name = "calyear";
  input->value = id->variables->calyear;
  fcontents += make_tag("input", input);

  input->name = "calmonth";
  input->value = id->variables->calmonth;
  fcontents += make_tag("input", input);

  input->name = "calday";
  input->value = id->variables->calday;
  fcontents += make_tag("input", input);

  input->name = "calweek";
  input->value = id->variables->calweek || "0";
  fcontents += make_tag("input", input);
  
  fcontents += make_tag("input", ds_changetype);
    
  tcontents += make_container("form", ds_form, fcontents) + "</td></tr>";
    
  return make_container("table", ds_table, tcontents);
}

static string make_monthyear_selector(object id, mapping my_args, object now, object target)
{
  mapping ds_row = ([]);
  mapping ds_cell = ([
    "align" : "center",
    "valign" : "top",
    "colspan" : id->misc->_calendar->cols
  ]);
  string   contents, contents1;
    
  ds_row->bgcolor = my_args->ds_bgcolor || QUERY(ds_bgcolor);
  contents = make_ds_form(id, my_args, now, target);
  return make_container("tr", ds_row,
                        make_container("td", ds_cell, contents));
}

static string make_weekdays_row(object id, mapping my_args, object now, object target)
{
  mapping  wd_row = ([]);
  mapping  wd_cell = ([]);
  string   rcontents = "";

  if (!my_args->nocss) {
    wd_row->class = my_args->wd_rowclass || QUERY(wd_rowclass);
    wd_cell->class = my_args->wd_cellclass || QUERY(wd_cellclass);
  }
    
  wd_row->bgcolor = my_args->wdr_bgcolor || QUERY(wdr_bgcolor);
  wd_cell->width = my_args->wdc_width || QUERY(wdc_width);
  wd_cell->align = "center";

  function      day_names = core->language(my_args->lang || id->variables->lang || 0, "day");
  string        days = "1234567";
  int           dnum = 1;
    
  if (!day_names) {
    days = en_days;
  } else {
    for (;dnum <= 7; dnum++)
      days[dnum - 1] = upper_case(day_names(dnum)[0..0])[0];
    dnum = 1;
  }

  if (id->misc->_calendar->sunday_pos == 7)
    days = days[1..6] + days[0..0];
    
  for(; dnum <= 7; dnum++) {
    if (my_args->nocss || dnum != id->misc->_calendar->sunday_pos)
      rcontents += make_container("td", wd_cell, days[(dnum - 1)..(dnum - 1)]);
    else {
      string oldc = wd_cell->class;
      int    spos = id->misc->_calendar->sunday_pos - 1;
            
      wd_cell->class = my_args->wd_sundayclass || QUERY(wd_sundayclass);
      rcontents += make_container("td", wd_cell, days[spos..spos]);
      wd_cell->class = oldc;
    }
  }

  return make_container("tr", wd_row, rcontents);
}

string make_monthdays_grid(object id, mapping my_args, object now,
                           object target, multiset active_days, multiset active_weeks)
{
  mapping   md_row = ([]);
  mapping   md_cell = ([]);
  mapping   md_weekcell = ([]);
  mapping   md_todaycell = ([]);
  mapping   md_text = ([]);
  mapping   md_todaytext = ([]);
  mapping   md_error = ([]);
  string    rcontents, ccontents, ret;
  multiset  adays = active_days || (<>);    
  multiset  aweeks = active_weeks || (<>);
  
  if (!my_args->nocss) {
    md_row->class = my_args->md_rowclass || QUERY(md_rowclass);
    md_cell->class = my_args->md_cellclass || QUERY(md_cellclass);
    md_weekcell->class = my_args->md_weekclass || QUERY(md_weekclass);
    md_todaycell->class = my_args->md_todaycellclass || QUERY(md_todaycellclass);
    md_text->class = my_args->md_textcellclass || QUERY(md_textclass);
    md_todaytext->class = my_args->md_todaytextclass || QUERY(md_todaytextclass);
    md_error->class = my_args->md_errorclass || QUERY(md_errorclass);
  }

  md_cell->width = my_args->wdc_width || QUERY(wdc_width);
  md_weekcell->width = my_args->wdc_width || QUERY(wdc_width);
  md_todaycell->width = my_args->wdc_width || QUERY(wdc_width);
  md_error->width = my_args->wdc_width || QUERY(wdc_width);;
    
  md_text->href = "javascript:void()";
  md_todaytext->href = "javascript:void()";
    
  int      x, y, doing_now, dow_start, curday, today;
  object   month;
    
  rcontents = "";
  ccontents = "";
  ret = "";
    
  today = (int)id->variables->calday;

  if (id->misc->_calendar && id->misc->_calendar->year_invalid) {
    md_error->colspan = id->misc->_calendar->cols;
    rcontents = make_container("td", md_error,
                               sprintf("Year out of range: %s", id->variables->calyear));
    return make_container("tr", md_row, rcontents);
  }
        
    
  if (!target) {
    md_error->colspan = id->misc->_calendar->cols;
    rcontents = make_container("td", md_error,
                               sprintf("Invalid date %s-%s-%s",
                                       id->variables->calyear,
                                       id->variables->calmonth,
                                       id->variables->calday));
    return make_container("tr", md_row, rcontents);
  }
    
  month = target->month();

  id->misc->_calendar->week = (string)target->week_no();
    
  array(object)  days = month->days();
  int            ndays = month->number_of_days(), grid_rows = 5;

  if (id->misc->_calendar->sunday_pos == 1)
    dow_start = days[0]->week_day() % 8;
  else
    dow_start = days[0]->week_day();
  curday = 0;

  if (ndays + dow_start > 36)
    grid_rows++;

  array(object) weeks = 0;

  if (my_args->do_week)
    weeks = target->month()->weeks();
  
  for(y = 1; y <= grid_rows; y++) {
    for(x = 1; x <= 7; x++) {
      if (curday >= ndays) {
        int extra_cells = (grid_rows * 7) - ndays - dow_start + 1;

        while(extra_cells--)
          rcontents += make_container("td", md_cell, "&nbsp;");
        break;
      }
            
      if (y == 1 && x < dow_start)
        ccontents = "&nbsp;";
      else {
        int  thisday = days[curday++]->month_day();

        if (adays[thisday]) {
          if (curday + 1 == today) {
            md_todaytext->onClick = sprintf("%s(%2d); return false;", QUERY(js_day), thisday);
            md_todaytext->onMouseOver = "window.status = ''; return true;";
            ccontents = make_container("a", md_todaytext, (string)thisday);
          } else {
            md_text->onClick = sprintf("%s(%2d); return false;", QUERY(js_day), thisday);
            md_text->onMouseOver = "window.status = ''; return true;";
            ccontents = make_container("a", md_text, (string)thisday);
          }
        } else
          ccontents = (string)thisday;
      }
            
      if (curday == today)
        rcontents += make_container("td", md_todaycell, ccontents);
      else
        rcontents += make_container("td", md_cell, ccontents);
    }

    int deckludge = month->month_no() == 12;
    
    if (weeks && sizeof(weeks) && y <= sizeof(weeks)) {
      int weekno = weeks[y - 1]->week_no();

      if (deckludge && weekno == 1)
        weekno = 53; // that's what ISO say we should do
      
      if (!aweeks[weekno])
        rcontents += make_container("td", md_weekcell, sprintf("%02d", weekno));
      else {
        md_text->onClick = sprintf("%s(%2d); return false;", QUERY(js_week), weekno);
        md_text->onMouseOver = "window.status = ''; return true;";
        ccontents = make_container("a", md_text, (string)weekno);
        rcontents += make_container("td", md_weekcell, ccontents);
      }
    }
    
    ret += make_container("tr", md_row, rcontents);
    rcontents = "";
  }
    
  return ret;
}

static void check_array(mapping var, string name)
{
  if (!var[name])
    return;

  array(string)  varray = var[name] / "\0";

  var[name] = varray[-1];
}

static int value_in_range(int val, array(mapping) range, int rel, void|int min, void|int max)
{
  if (!range || !sizeof(range))
    return 0;

  if (!zero_type(min) && val < min)
    return 0;

  if (!zero_type(max) && val > max)
    return 0;  
  
  int  checks_counter;
  
  foreach(range, mapping r) {
    checks_counter = -1;
    
    if (rel < 0) { // before?
      if (r->rend >= 0 && val < r->rend)
        checks_counter++;
      else if (r->rend < 0)
        checks_counter++;
      else
        checks_counter--;      
    } else if (!rel) { // in range?
      if (r->rstart >= 0 && val >= r->rstart)
        checks_counter++;
      else if (r->rstart < 0)
        checks_counter++;
      else
        checks_counter--;
      
      if (r->rend >= 0 && val <= r->rend)
        checks_counter++;
      else if (r->rend < 0 && val == r->rstart)
        checks_counter++;
      else
        checks_counter--;
    } else { // after?
      if (r->rstart >= 0 && val > r->rstart)
        checks_counter++;
      else if (r->rstart < 0)
        checks_counter++;
      else
        checks_counter--;
    }

    if (checks_counter >= 0)
      break;
  }

  if (checks_counter >= 0)
    return 1;
  
  return 0;
}

static multiset check_in_range(object date, mapping range, int maxdays)
{
  int      day, month, year, week;
  mixed    error;
  multiset ret = (<>);
  
  if (!range || !date)
    return 0;

  day = date->month_day();
  month = date->month_no();
  year = date->year_no();
  week = date->week_no();

  if (range->before) {
    int y, m, d, w;

    // take the minimum day, month, week and year from the passed ranges
    // (if any) and store them in the above variables
    y = 0;
    if (range->years) {
      foreach(range->years, mapping mp)
        if (mp->rend > 0 && mp->rend > y)
          y = mp->rend;
        else if (mp->rstart > 0 && mp->rstart > y)
          y = mp->rstart;
    }

    m = 0;
    if (range->months) {
      foreach(range->months, mapping mp)
        if (mp->rend && mp->rend > m)
          m = mp->rend;
        else if (mp->rstart > 0 && mp->rstart > m)
          m = mp->rstart;
    }

    d = 0;
    if (range->days) {
      foreach(range->days, mapping mp)
        if (mp->rend && mp->rend > d)
          d = mp->rend;
        else if (mp->rstart > 0 && mp->rstart > d)
          d = mp->rstart;
    }

    w = 0;
    if (range->weeks) {
      foreach(range->weeks, mapping mp)
        if (mp->rend && mp->rend > w)
          w = mp->rend;
        else if (mp->rstart > 0 && mp->rstart > w)
          w = mp->rstart;
    }

    // accept only dates where ymd, md or ym are set, other dates are ignored
    if ((y && m && d) || (m && d) || (y && m)) {
      if (year > y || (year == y && month > m))
        return ret;
      if (!d) // no day? Should we return all days in the month?
        return ret;
      for (int i = 1; i <= maxdays; i++)
        if (year < y || month < m || i < d)
          ret += (<i>);
      return ret;
    }

    return ret;
  }

  if (range->after) {
    int y, m, d, w;

    // take the maximum day, month, week and year from the passed ranges
    // (if any) and store them in the above variables
    y = 100000;
    if (range->years) {
      foreach(range->years, mapping mp)
        if (mp->rstart > 0 && mp->rstart < y)
          y = mp->rstart;
    }

    m = 13;
    if (range->months) {
      foreach(range->months, mapping mp)
        if (mp->rstart && mp->rstart < m)
          m = mp->rstart;
    }

    d = 32;
    if (range->days) {
      foreach(range->days, mapping mp)
        if (mp->rstart && mp->rstart < d)
          d = mp->rstart;
    }

    w = 53;
    if (range->weeks) {
      foreach(range->weeks, mapping mp)
        if (mp->rstart && mp->rstart < w)
          w = mp->rstart;
    }

    if (((y != 100000) && (m != 13) && (d != 32)) || ((m != 13) && (d != 32)) || ((y != 100000) && (m != 13))) {
      if ((y != 100000 && year < y) || (year == y && (m != 13 && month < m)))
        return ret;
      if (y == 100000 && m != 13 && month < m)
        return ret;
      if (!d)
        return ret;
      for (int i = 1; i <= maxdays; i++)
        if (year > y || month > m || i > d)
          ret += (<i>);
      return ret;
    }

    return ret;
  }
    
  if (range->years)
    if (!value_in_range(year, range->years, 0))
      return ret;

  if (range->months)
    if (!value_in_range(month, range->months, 0, 1, 12))
      return ret;

  if (range->weeks)
    if (!value_in_range(week, range->weeks, 0, 1, 53))
      return ret;
  
  for (int i = 1; i <= maxdays; i++) {
    if (!range->days) {
      return ret;
    } else {
      if (value_in_range(i, range->days, 0, 1, maxdays))
        ret += (<i>);
    }
  }
  
  return ret;
}

static multiset mark_active_weeks(object target, object id)
{
  if (!target || !objectp(target))
    return (<>);    

  if (!id->misc->_calendar->hotdates || !sizeof(id->misc->_calendar->hotdates))
    return (<>);
  
  multiset      ret = (<>);
  array(object) weeks = target->month()->weeks();
  int           deckludge = target->month_no() == 12;
  
  foreach(id->misc->_calendar->hotdates, mapping range) {
    if (range->weeks && sizeof(range->weeks))
      foreach(weeks, object week) {
        int weekno = week->week_no();
        
        if (value_in_range(weekno, range->weeks, 0, 1, 53))
          if (deckludge && weekno == 1)
            ret += (<53>);
          else
            ret += (<weekno>);
      }
  }

  return ret;
}

static multiset mark_active_days(object target, object id)
{
  if (!target || !objectp(target))
    return (<>);    

  if (!id->misc->_calendar->hotdates || !sizeof(id->misc->_calendar->hotdates))
    return (<>);
  
  multiset ret = (<>);
  int      maxdays;

  maxdays = sizeof(target->month()->days());

  multiset day_matches = 0;

  foreach(id->misc->_calendar->hotdates, mapping range) {
    if (range->before) {
      day_matches = check_in_range(target, range, maxdays);
      if (day_matches) {
        ret += day_matches;
        continue;
      }
    }

    if (range->after) {
      day_matches = check_in_range(target, range, maxdays);
      if (day_matches) {
        ret += day_matches;
        continue;
      }
    }

    day_matches = check_in_range(target, range, maxdays);
    if (day_matches)
      ret += day_matches;
  }
  
  return ret;
}

static array(mapping) parse_ranges(string c)
{
  if (!c || !sizeof(c))
    return ({});
  
  string    tmp = replace(c, ({" ", "\t", "\n", "\r"}), ({"", "", "", ""}));

  if (!sizeof(tmp))
    return ({});
  
  array(mapping)    ret = ({});  
  int               rstart, rend;
  
  foreach((tmp / ",") - ({}) - ({""}), string part) {
    rstart = -1;
    rend = -1;
    
    if (has_value(part, "-")) {
      // we have a range, parse it
      switch(sscanf(part, "%d-%d", rstart, rend)) {
          case 0:
            rstart = rend = 0;
            break;
            
          case 1:
            if (rstart < 0)
              rstart *= -1;
            rend = -1;
            break;
      }
    } else {
      if (sscanf(part, "%d%*s", rstart) < 1)
        rstart = 0;
      rend = -1;
    }

    ret += ({([
      "rstart" : rstart,
      "rend" : rend
    ])});
  };

  return ret;
}

// inner tags
static string startdate_tag(string tag, mapping args, object id)
{
  int    when, wday, wmonth, wyear;
  mixed  error;
  object now, then;

  if (!id->misc->_calendar || !id->misc->_calendar->inside_calendar)
    return "";
  
  error = catch {
    now = Calendar.now();
  };

  if (error)
    wday = wmonth = wyear = -1;
  else {
    wday = now->month_day();
    wmonth = now->month_no();
    wyear = now->year_no();
  }
  
  if (!args || !sizeof(args) || args->today)
    when = 0;
  else if (args->yesterday)
    when = -1;
  else if (args->tomorrow)
    when = 1;
  else {
    array(mapping)   range;
    
    if (args->day) {
      range = parse_ranges(args->day);
      if (range && sizeof(range)) 
        wday = range[0]->rstart;
    }

    if (args->month) {
      range = parse_ranges(args->month);
      if (range && sizeof(range)) 
        wmonth = range[0]->rstart;
    }

    if (args->year) {
      range = parse_ranges(args->year);
      if (range && sizeof(range)) 
        wyear = range[0]->rstart;
    }

    when = 2;
  }

  switch (when) {
      case -1:
        if (wday > 0 && now) {
          then = now->day()->prev();
          wday = then->month_day();
          wmonth = then->month_no();
          wyear = then->year_no();
        }
        break;

      case 1:
        if (wday > 0 && now) {
          then = now->day()->next();
          wday = then->month_day();
          wmonth = then->month_no();
          wyear = then->year_no();
        }
        break;
  }

  error = catch {
    id->misc->_calendar->start_day = (string)wday;
    id->misc->_calendar->start_month = (string)wmonth;
    id->misc->_calendar->start_year = (string)wyear;
  };

  return "<!-- start date set -->";
}

static private mapping how_dir = ([
  "before" : "prev",
  "after" : "next"
]);

static array(mapping) make_ba_range(object date, string when, string how)
{
  string           fun;

  if (!date || !when || !sizeof(when))
    return ({});

  fun = how_dir[how];
  if (!fun || !sizeof(fun))
    return ({});

  object           then;
  mapping          range = ([]);

  range[how] = 1;

  switch(when) {
      case "today":
        then = date;
        break;

      case "yesterday":
        then = date->day()->prev()->day()[fun]();
        break;
        
      case "tomorrow":
        then = date->day()->next();
        break;

      default:
        return ({});
  }

  range->days = ({([
    "rstart" : then->month_day(),
    "rend" : -1
  ])});
  
  range->months = ({([
    "rstart" : then->month_no(),
    "rend" : -1
  ])});
  
  range->years = ({([
    "rstart" : then->year_no(),
    "rend" : -1
  ])});

  return ({range});
}

static string hotdate_tag(string tag, mapping args, object id)
{
  multiset   relative = (<"tomorrow", "today", "yesterday", "specified">);

  if (!id->misc->_calendar || !id->misc->_calendar->inside_calendar)
    return "";
  
  if (!args || !sizeof(args))
    return "";

  array(mapping)   days;
  array(mapping)   months;
  array(mapping)   years;
  array(mapping)   weeks;
  string           before, after;

  if (!id->misc->_calendar->hotdates)
    id->misc->_calendar->hotdates = ({});
  
  if (args->after && relative[lower_case(args->after)])
    after = lower_case(args->after);
  
  else if (args->before && relative[lower_case(args->before)])
    before = lower_case(args->before);

  if ((!before && !after) || after == "specified" || before == "specified") {
    if (args->day)
      days = parse_ranges(args->day);
    if (args->month)
      months = parse_ranges(args->month);
    if (args->year)
      years = parse_ranges(args->year);
    if (args->week) 
      weeks = parse_ranges(args->week);
    
    // construct a combined range
    mapping   range = ([
      "days" : days,
      "months" : months,
      "years" : years,
      "weeks" : weeks
    ]);

    if (after)
      range->after = 1;
    if (before)
      range->before = 1;

    id->misc->_calendar->hotdates += ({range});
  } else if (before || after) {
    mapping  range;
    mixed    error;
    object   now, then;

    error = catch {
      now = Calendar.now();
    };

    if (!error) {
      if (after)
        id->misc->_calendar->hotdates += make_ba_range(now, after, "after");
        
      if (before)
        id->misc->_calendar->hotdates += make_ba_range(now, before, "before");
    }
  }
  
  return "<!-- hotdate processed -->";
}

string calendar_tag(string tag, mapping args, string cont,
                    object id, object f, mapping defines)
{
  mapping    my_args;
  mapping    main_table = ([]);
  string     contents = "", tmp;
  multiset   active_days, active_weeks;
  mixed      error;
  
  if (!id->misc->_calendar)
    id->misc->_calendar = ([]);

  id->misc->_calendar->inside_calendar = 1;
  
  error = catch {
    tmp = parse_rxml(cont, id);
  };  

  id->misc->_calendar->inside_calendar = 0;
  
  if (id->misc->_calendar->hotdates)
    id->misc->_calendar->hotdates -= ({({})});
  
  if (!args)
    my_args = ([]);
  else
    my_args = args + ([]);
    
  main_table->width = my_args->mt_width || "200";
  main_table->cellspacing = my_args->mt_cellspacing || "1";
  main_table->cellpadding = my_args->mt_cellpadding || "1";
  main_table->bgcolor = my_args->mt_bgcolor || QUERY(mt_bgcolor);
  if (!my_args->nocss)
    main_table->class = my_args->mt_class || QUERY(mt_class);
    
  main_table->border = "0";
    
  object now;
  object target;
    
  if (stringp(my_args->weekstart) && sizeof(my_args->weekstart) && lower_case(my_args->weekstart)[0] == 's') {
    id->misc->_calendar->sunday_pos = 1;
    now = Calendar.Gregorian.now();
  } else {
    id->misc->_calendar->sunday_pos = 7;
    now = Calendar.now();
  }

  if (!id->variables->calyear) {
    if (!id->misc->_calendar->start_year || (int)id->misc->_calendar->start_year <= 0)
      id->variables->calyear = (string)now->year_no();
    else
      id->variables->calyear = id->misc->_calendar->start_year;
  } else
    check_array(id->variables, "calyear");
    
  if (!id->variables->calmonth) {
    if (!id->misc->_calendar->start_month || (int)id->misc->_calendar->start_month <= 0)
      id->variables->calmonth = (string)now->month_no();
    else
      id->variables->calmonth = id->misc->_calendar->start_month;
  } else
    check_array(id->variables, "calmonth");
    
  if (!id->variables->calday) {
    if (!id->misc->_calendar->start_day || (int)id->misc->_calendar->start_day <= 0)
      id->variables->calday = (string)now->month_day();
    else
      id->variables->calday = id->misc->_calendar->start_day;
  } else
    check_array(id->variables, "calday");
    
  if (my_args->do_week)
    id->misc->_calendar->cols = "8";
  else
    id->misc->_calendar->cols = "7";

  if (id->misc->_calendar->sunday_pos == 7)
    target = Calendar.parse("%Y-%M-%D", sprintf("%s-%s-%s",
                                                id->variables->calyear,
                                                id->variables->calmonth,
                                                id->variables->calday));
  else
    target = Calendar.Gregorian.parse("%Y-%M-%D", sprintf("%s-%s-%s",
                                                          id->variables->calyear,
                                                          id->variables->calmonth,
                                                          id->variables->calday));
  
  active_days = mark_active_days(target, id);
  active_weeks = mark_active_weeks(target, id);
  
  contents += make_monthyear_selector(id, my_args, now, target);
  contents += make_weekdays_row(id, my_args, now, target);
  contents += make_monthdays_grid(id, my_args, now, target, active_days, active_weeks);
    
  return tmp +make_container("table", main_table, contents);
}

static multiset  changetypes = (<"day", "week">);

string calendar_action_tag(string tag, mapping args, string cont,
                           object id, object f, mapping defines)
{
  mapping     myargs = args || ([]);
  int         doit = 0;
  array(int)  wanted = allocate(3), has = allocate(3);
  
  if (!id->variables->year || !id->variables->month || !id->variables->changetype)
    // not a submission from the calendar form
    return "";

  if (!myargs->default && !changetypes[id->variables->changetype])
    return "";

  if (myargs->default)
    return parse_rxml(cont, id);

  array(mapping)  weeks;
  array(mapping)  days;
  array(mapping)  months;
  array(mapping)  years;

  if (myargs->week && sizeof(myargs->week))
    weeks = parse_ranges(myargs->week);
  if (myargs->day && sizeof(myargs->day))
    days = parse_ranges(myargs->day);
  if (myargs->month && sizeof(myargs->month))
    months = parse_ranges(myargs->month);
  if (myargs->year && sizeof(myargs->year))
    years = parse_ranges(myargs->year);

  mixed error = catch {
    if (days && sizeof(days) && !value_in_range((int)id->variables->calday, days, 0, 1, 31))
      return "";
    if (months && sizeof(months) && !value_in_range((int)id->variables->calmonth, months, 0, 1, 12))
      return "";
    if (years && sizeof(years) && !value_in_range((int)id->variables->calyear, years, 1))
      return "";
    if (weeks && sizeof(weeks) && !value_in_range((int)id->variables->calweek, weeks, 0, 1, 53))
      return "";
  };

  if (error) {
    report_error("Calendar: error in the action handler. Backtrace:\n%O\n", error);
    return "<!-- error in the calendar action handler. See the logs for more information. -->";
  }
  
  if (id->variables->changetype == "week" && id->variables->calday == "1")
    return "";
  
  // something matches, go ahead.
  string ret = parse_rxml(cont, id);

  return ret;
}

string calendar_js_tag(string tag, mapping args,
                       object id, object f, mapping defines)
{
  return replace(default_js, "@calendarform@", QUERY(ds_formname));
}

string calendar_css_tag(string tag, mapping args,
                        object id, object f, mapping defines)
{
  return default_css;
}

mapping query_container_callers()
{
  return ([
    "calendar" : calendar_tag,
    "calendar-action" : calendar_action_tag,
    "calendar_action" : calendar_action_tag
  ]);
}

mapping query_tag_callers()
{
  return ([
    "calendar-js" : calendar_js_tag,
    "calendar_js" : calendar_js_tag,
    "calendar-css" : calendar_css_tag,
    "calendar_css" : calendar_css_tag,
    "hotdate" : hotdate_tag,
    "startdate" : startdate_tag
  ]);
}

// some major uglinness
// put last so that it doesn't blur the code
static private string default_js = #"
<script language=\"JavaScript\">
function disp_month()
{
      var mymonth=document.@calendarform@.month.options[document.@calendarform@.month.selectedIndex].value;
      var myyear=document.@calendarform@.year.options[document.@calendarform@.year.selectedIndex].value;
      var myday='1';

      document.@calendarform@.calyear.value = myyear;
      document.@calendarform@.calmonth.value = mymonth;
      document.@calendarform@.calday.value = myday;
      document.@calendarform@.calweek.value = '0';
      document.@calendarform@.changetype.value = \"month\";

      document.@calendarform@.submit();
}

function disp_year()
{
      var mymonth=document.@calendarform@.month.options[document.@calendarform@.month.selectedIndex].value;
      var myyear=document.@calendarform@.year.options[document.@calendarform@.year.selectedIndex].value;
      var myday='1';

      document.@calendarform@.calyear.value = myyear;
      document.@calendarform@.calmonth.value = mymonth;
      document.@calendarform@.calday.value = myday;
      document.@calendarform@.calweek.value = '0';
      document.@calendarform@.changetype.value = \"year\";

      document.@calendarform@.submit();
}

function disp_day(daynum)
{
      var mymonth=document.@calendarform@.month.options[document.@calendarform@.month.selectedIndex].value;
      var myyear=document.@calendarform@.year.options[document.@calendarform@.year.selectedIndex].value;

      document.@calendarform@.calyear.value = myyear;
      document.@calendarform@.calmonth.value = mymonth;
      document.@calendarform@.calday.value = daynum;
      document.@calendarform@.calweek.value = '0';
      document.@calendarform@.changetype.value = \"day\";

      document.@calendarform@.submit();
}

function disp_week(weeknum)
{
      var mymonth=document.@calendarform@.month.options[document.@calendarform@.month.selectedIndex].value;
      var myyear=document.@calendarform@.year.options[document.@calendarform@.year.selectedIndex].value;

      document.@calendarform@.calyear.value = myyear;
      document.@calendarform@.calmonth.value = mymonth;
      document.@calendarform@.calweek.value = weeknum;
      document.@calendarform@.changetype.value = \"week\";

      document.@calendarform@.submit();
}

</script>";

static private string default_css = #"<style type=\"text/css\">
td.cal-td {
      background: #ffffff;
      font-weight: bold;
      font-family: sans-serif;
      text-align: center;
}

td:hover.cal-td {
      background: #efefef;
      font-weight: bold;
      font-family: sans-serif;
      text-align: center;
}

td.cal-today {
      background: #cfcfcf;
      font-weight: bold;
      font-family: sans-serif;
      text-align: center;
}

td.cal-tdsunday {
      color: #ff0000;
      background: #ffffff;
      font-weight: bold;
      font-family: sans-serif;
      text-align: center;
}

td.cal-error {
      background: #ff0000;
      font-weight: bold;
      font-family: sans-serif;
      text-align: center;
      color: yellow; 
}

td.cal-weekdata {
      background: #edebcb;
      font-weight: bold;
      font-family: sans-serif;
      text-align: center;
}

a.cal-text {
      color: #0453ab;
      text-decoration: none;
}

a:hover.cal-text {
      color: #0453ab;
      text-decoration: none;
}

a.cal-todaytext {
      color: #0453ab;
      text-decoration: none;
}

a:hover.cal-todaytext {
      color: #0453ab;
      text-decoration: none;
}
</style>";

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: mt_bgcolor
//! Color of the main table background
//!  type: TYPE_STRING
//!  name: Colors: Main table background
//
//! defvar: ds_bgcolor
//! Color of the date selector background
//!  type: TYPE_STRING
//!  name: Colors: Date selector background
//
//! defvar: wdr_bgcolor
//! Color of the weekdays row background
//!  type: TYPE_STRING
//!  name: Colors: Weekdays row background
//
//! defvar: mt_class
//! Main table CSS class name
//!  type: TYPE_STRING
//!  name: CSS Classes: Main table
//
//! defvar: ds_monthclass
//! Month selector CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Month selector
//
//! defvar: ds_yearclass
//! Year selector CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Year selector
//
//! defvar: wd_rowclass
//! Weekdays row CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Weekdays row
//
//! defvar: wd_cellclass
//! Weekdays cell CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Weekdays cell
//
//! defvar: wd_sundayclass
//! Weekdays Sunday cell CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Weekdays Sunday cell
//
//! defvar: md_rowclass
//! Month days row CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Month days row
//
//! defvar: md_cellclass
//! Month days cell CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Month days cell
//
//! defvar: md_todaycellclass
//! Month days 'today' cell CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Month days 'today' cell
//
//! defvar: md_textclass
//! Month days cell text CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Month days cell text
//
//! defvar: md_todaytextclass
//! Month days 'today' cell text CSS class name.
//!  type: TYPE_STRING
//!  name: CSS Classes: Month days 'today' cell text
//
//! defvar: md_errorclass
//! CSS class name for the 'Invalid date' message cell.
//!  type: TYPE_STRING
//!  name: CSS Classes: Invalid date
//
//! defvar: md_weekclass
//! CSS class name for week number cell.
//!  type: TYPE_STRING
//!  name: CSS Classes: Week number cell
//
//! defvar: ds_formname
//! Name of the form element that contains the date selector.
//!  type: TYPE_STRING
//!  name: Names: Calendar form name
//
//! defvar: js_month
//! Name of the function that will handle the month change.
//!  type: TYPE_STRING
//!  name: JavaScript: Month change function
//
//! defvar: js_year
//! Name of the function that will handle the year change.
//!  type: TYPE_STRING
//!  name: JavaScript: Year change function
//
//! defvar: js_day
//! Name of the function that will handle the day change.
//!  type: TYPE_STRING
//!  name: JavaScript: Day change function
//
//! defvar: js_week
//! Name of the function that will handle the week click.
//!  type: TYPE_STRING
//!  name: JavaScript: Week click function
//
//! defvar: wdc_width
//! Width of a single cell in the calendar grid. In percent.
//!  type: TYPE_STRING
//!  name: Dimensions: Width of the calendar cells
//
