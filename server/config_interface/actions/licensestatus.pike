/*
 * $Id: licensestatus.pike,v 1.4 2002/03/07 16:43:31 wellhard Exp $
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
  <font size='+1'>Installed Licenses</font>
  <input type='hidden' name='action' value='&form.action;'/>
  <input type='hidden' name='class' value='&form.class;'/>
  <table>
    <tr>
      <th align='left'>Filename</th>
      <th align='left'>#</th>
      <th align='left'>Type</th>
      <th align='left'>Status</th>
    </tr>
    <emit source='licenses'>
      <tr>
        <td><a href='?action=&form.action;&amp;class=&form.class;&amp;license=&_.filename;'
          >&_.filename;</a>&nbsp;&nbsp;&nbsp;</td>
        <td>&_.number;&nbsp;&nbsp;&nbsp;</td>
        <td>&_.type;&nbsp;&nbsp;&nbsp;</td>
        <td>
          <emit source='license-warnings' rowinfo='var.warnings'></emit>
          <if variable='var.warnings > 0'>Warnings detected</if>
          &nbsp;&nbsp;&nbsp;
        </td>
      </tr>
    </emit>
  </table>

  <if variable='form.license'>
    <hr />
    <font size='+1'>License &form.license;</font>
      <license name='&form.license;'>
      <table>
        <tr><td>Company Name:</td><td>&_.company_name;</td></tr>
        <tr><td>Expires:</td><td>&_.expires;</td></tr>
        <tr><td>Hostname:</td><td>&_.hostname;</td></tr>
        <tr><td>Type:</td><td>&_.type;</td></tr>
        <tr><td>Number:</td><td>&_.number;</td></tr>
        <tr><td>Created:</td><td>&_.created;</td></tr>
        <tr><td>Created by:</td><td>&_.creator;@roxen.com</td></tr>
      </table><br />
      <table>
        <tr>
          <th align='left'>Module</th>
          <th align='left'>Enabled</th>
          <th align='left'>Features</th>
        </tr>
        <emit source='license-modules'>
          <tr>
            <td><e>&_.name;</e></td>
            <td align='center'>&_.enabled;</td>
            <td>
              <emit source='license-module-features'
                >&_.name;:&nbsp;&_.value;<delimiter>,&nbsp;</delimiter></emit>
              <else>&nbsp;</else>
            </td>
          </tr>
        </emit>
      </table>
      <emit source='license-warnings' rowinfo='var.warnings'></emit>
      <if variable='var.warnings > 0'>
        <table>
          <tr>
            <th align='left'>Type</th>
            <th align='left'>Warning</th>
            <th align='left'>Time</th>
          </tr>
          <emit source='license-warnings'>
            <tr>
              <td>&_.type;&nbsp;&nbsp;&nbsp;</td>
              <td nowrap=''>&_.msg;&nbsp;&nbsp;&nbsp;</td>
              <td><date type='iso' unix-time='&_.time;'/>&nbsp;&nbsp;&nbsp;</td>
            </tr>
          </emit>
        </table>
      </if>
    </license>
  </if>
";
  return txt;
}
