/*
 * $Id: licensestatus.pike,v 1.1 2002/03/06 16:21:23 wellhard Exp $
 */

#include <roxen.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "status";

string name= LOCALE(0, "License status");
string doc = LOCALE(0, "Show information about the installed licenses and "
		    "there usage.");


mixed parse( RequestID id )
{
  string txt = #"
  <h1>Installed Licenses</h1>
  <input type='hidden' name='action' value='&form.action;'/>
  <input type='hidden' name='class' value='&form.class;'/>
  <table>
    <tr>
      <th align='left'>Filename</th>
      <th align='left'>#</th>
      <th align='left'>Type</th>
    </tr>
    <emit source='licenses'>
      <tr>
        <td><a href='?action=&form.action;&amp;class=&form.class;&amp;license=&_.filename;'
          >&_.filename;</a>&nbsp;&nbsp;&nbsp;</td>
        <td>&_.number;&nbsp;&nbsp;&nbsp;</td>
        <td>&_.type;&nbsp;&nbsp;&nbsp;</td>
      </tr>
    </emit>
  </table>

  <if variable='form.license'>
    <hr />
    <h1>License &form.license;</h1>
      <license name='&form.license;'>
      <table>
        <tr><td><e>Company Name:</e></td><td>&_.company_name;</td></tr>
        <tr><td><e>Expires:</e></td><td>&_.expires;</td></tr>
        <tr><td><e>Hostname:</e></td><td>&_.hostname;</td></tr>
        <tr><td><e>Type:</e></td><td>&_.type;</td></tr>
        <tr><td><e>Number:</e></td><td>&_.number;</td></tr>
        <tr><td><e>Created:</e></td><td>&_.created;</td></tr>
        <tr><td><e>Created by:</e></td><td>&_.creator;@roxen.com</td></tr>
      </table>
      <h2>Modules</h2>
      <table>
        <tr>
          <th align='left'>Module</th>
          <th align='left'>Status</th>
          <th align='left'>Features</th>
        </tr>
        <emit source='license-modules'>
          <tr>
            <td><e>&_.name;</e></td>
            <td align='center'>&_.enabled;</td>
            <td>
              <emit source='license-module-features'>
                &_.name;: &_.value;
                <delimiter>,</delimiter>
              </emit><else>&nbsp;</else>
            </td>
          </tr>
        </emit>
      </table>
    </license>
  </if>
";
  RXML.Parser parser = Roxen.get_rxml_parser (id);
  parser->write_end(txt);
 
  return parser->eval();
}
