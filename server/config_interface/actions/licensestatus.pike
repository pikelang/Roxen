/*
 * $Id$
 */

#include <roxen.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "status";

string name= LOCALE(165, "License status");
string doc = LOCALE(166, "Show information about the installed licenses and "
		    "their usage.");

int enabled()
{
  return License.is_active(getenv("ROXEN_LICENSEDIR") || "../license");
}

mixed parse( RequestID id )
{
  string txt = #"
  <font size='+1'><b>Installed Licenses</b></font>
  <p>
  Click on a license for more information.
  </p>
  <input type='hidden' name='action' value='&form.action;'/>
  <input type='hidden' name='class' value='&form.class;'/>
  <box-frame width='100%' iwidth='100%' bodybg='&usr.content-bg;' box-frame='yes' padding='0'>
  <table cellspacing='0' cellpadding='3' border='0' width='100%'>
    <tr bgcolor='&usr.obox-titlebg;'>
      <td>&nbsp;</td>
      <th align='left'>Filename</th>
      <th align='left'>#</th>
      <th align='left'>Type</th>
      <th align='left'>Status</th>
      <th align='left'>Used in</th>
    </tr>
    <set variable='var.color1'>&usr.obox-bodybg;</set>
    <set variable='var.color2'>&usr.fade1;</set>
    <set variable='var.color'>&var.color2;</set>
    <emit source='licenses'>
      <if variable='var.color == &var.color1;'>
        <set variable='var.color'>&var.color2;</set>
      </if><else>
        <set variable='var.color'>&var.color1;</set>
      </else>  
      <tr bgcolor='&var.color;'>
        <td width='10'>
          <if variable='form.license == &_.filename;'>
            <imgs src='&usr.selected-indicator;' border='0'/></if><else>&nbsp;</else></td>
        <td>
          <if variable='_.malformed != yes'>
            <if variable='form.license == &_.filename;'>
              <b>&_.filename;</b>
            </if>
            <else>
              <a href='?action=&form.action;&amp;class=&form.class;&amp;license=&_.filename;&amp;&usr.set-wiz-id;'>&_.filename;</a>
            </else>
          </if>
          <else>&_.filename;</else>
        </td>
        <td>&_.number;</td>
        <td>
          <if variable='_.malformed == yes'>
            <font color='darkred'>error</font></if>
          <else>&_.type;</else>
        </td>
        <td>
          <if variable='_.malformed != yes'>
            <emit source='license-warnings' rowinfo='var.warnings'></emit>
            <if variable='var.warnings > 0'>Detected &var.warnings;
              warning<if variable='var.warnings > 1'>s</if></if>
          </if>
          <else>&_.reason;</else>
          &nbsp;
        </td>
        <td>&_.configurations;&nbsp;</td>
      </tr>
    </emit>
  </table>
  </box-frame>

  <if variable='form.license'>
    <br clear='all'/><br />
    <font size='+1'>License &form.license;</font>
    <br /><br />
    <license name='&form.license;'>
      <table>
        <tr><td><b>Company Name:</b></td><td>&_.company_name;</td></tr>
        <tr><td><b>Expires:</b></td><td>&_.expires;</td></tr>
        <tr><td><b>Hostname:</b></td><td>&_.hostname;</td></tr>
        <tr><td><b>Type:</b></td><td>&_.type;</td></tr>
        <tr><td><b>Sites:</b></td><td>&_.sites;</td></tr>
        <tr><td><b>Number:</b></td><td>&_.number;</td></tr>
        <tr><td><b>Created:</b></td><td>&_.created;</td></tr>
        <tr><td><b>Created by:</b></td><td>&_.creator;@roxen.com</td></tr>
        <tr><td><b>Comment:</b></td><td>&_.comment;</td></tr>
      </table><br />
      <box-frame width='100%' iwidth='100%' bodybg='&usr.content-bg;' box-frame='yes' padding='0'>
      <table cellspacing='0' border='0' cellpadding='3' width='100%'>
        <tr bgcolor='&usr.obox-titlebg;'>
          <th align='left'>Module</th>
          <th align='center'>Enabled</th>
          <th align='left'>Features</th>
        </tr>
        <set variable='var.color'>&var.color2;</set>
        <emit source='license-modules'>
          <if variable='var.color == &var.color1;'>
            <set variable='var.color'>&var.color2;</set>
          </if><else>
            <set variable='var.color'>&var.color1;</set>
          </else>  
          <tr bgcolor='&var.color;'>
            <td><e>&_.name;</e></td>
            <td align='center'>&_.enabled;</td>
            <td nowrap=''>
              <emit source='license-module-features'
                >&_.name;:&nbsp;&_.value;<delimiter><br /></delimiter></emit>
              <else>&nbsp;</else>
            </td>
          </tr>
        </emit>
      </table>
      </box-frame>
      <emit source='license-warnings' rowinfo='var.warnings'></emit>
      <if variable='var.warnings > 0'>
        <br clear='all'/><br />
        <b>Warnings</b>
        <box-frame width='100%' iwidth='100%' bodybg='&usr.content-bg;' box-frame='yes' padding='0'>
        <table cellspacing='0' cellpadding='3' border='0' width='100%'>
          <tr bgcolor='&usr.obox-titlebg;'>
            <th align='left'>Type</th>
            <th align='left'>Warning</th>
            <th align='left'>Time</th>
          </tr>
          <set variable='var.color'>&var.color2;</set>
          <emit source='license-warnings'>
            <if variable='var.color == &var.color1;'>
              <set variable='var.color'>&var.color2;</set>
            </if><else>
              <set variable='var.color'>&var.color1;</set>
            </else>  
            <tr bgcolor='&var.color;'>
              <td nowrap='' valign='top'>&_.type;&nbsp;&nbsp;&nbsp;</td>
              <td valign='top'>&_.msg;&nbsp;</td>
              <td valign='top'><date type='iso' unix-time='&_.time;'/>&nbsp;</td>
            </tr>
          </emit>
        </table>
        </box-frame>
      </if>
    </license>
  </if>
  <input type=hidden name=action value='licensestatus.pike' />
  <br clear='all'/>
  <br />
  <cf-ok-button href='./'/>
";
  return txt;
}
