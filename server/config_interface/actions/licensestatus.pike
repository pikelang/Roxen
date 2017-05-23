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
  <h2 class='no-margin-top'>Installed Licenses</h2>
  <p>Click on a license for more information.</p>
  <input type='hidden' name='action' value='&form.action;'/>
  <input type='hidden' name='class' value='&form.class;'/>

  <table class='nice'>
    <thead>
      <tr>
        <th>Filename</th>
        <th>#</th>
        <th>Type</th>
        <th>Status</th>
        <th>Used in</th>
      </tr>
    </thead>
    <emit source='licenses'>
      <tr>
        <td>
          <if variable='_.malformed != yes'>
            <if variable='form.license == &_.filename;'>
              <b>&_.filename;</b>
            </if>
            <else>
              <a href='?action=&form.action;&amp;class=&form.class;&amp;license=&_.filename;&amp;&usr.set-wiz-id;'>&_.filename;</a>
            </else>
          </if>
          <else><div class='notify warning inline'>&_.filename;</div></else>
        </td>
        <td>&_.number;</td>
        <td>
          <if variable='_.malformed == yes'>
            <span class='error'>error</span></if>
          <else>&_.type;</else>
        </td>
        <td>
          <if variable='_.malformed != yes'>
            <emit source='license-warnings' rowinfo='var.warnings'></emit>
            <if variable='var.warnings > 0'>
              <div class='notify warning inline'>Detected &var.warnings;
              warning<if variable='var.warnings > 1'>s</if></div>
            </if>
          </if>
          <else>&_.reason;</else>
        </td>
        <td>&_.configurations;</td>
      </tr>
    </emit>
  </table>

  <if variable='form.license'>
    <h3>License &form.license;</h3>
    <license name='&form.license;'>
      <table class='auto'>
        <tr><th>Company Name:</th><td>&_.company_name;</td></tr>
        <tr><th>Expires:</th><td>&_.expires;</td></tr>
        <tr><th>Hostname:</th><td>&_.hostname;</td></tr>
        <tr><th>Type:</th><td>&_.type;</td></tr>
        <tr><th>Sites:</th><td>&_.sites;</td></tr>
        <tr><th>Number:</th><td>&_.number;</td></tr>
        <tr><th>Created:</th><td>&_.created;</td></tr>
        <tr><th>Created by:</th><td>&_.creator;@roxen.com</td></tr>
        <tr><th>Comment:</th><td>&_.comment;</td></tr>
      </table>

      <hr class='section'>

      <table class='nice valign-top'>
        <thead>
          <tr>
            <th>Module</th>
            <th>Enabled</th>
            <th>Features</th>
          </tr>
        </thead>
        <tbody>
          <emit source='license-modules'>
            <tr>
              <td><e>&_.name;</e></td>
              <td>&_.enabled;</td>
              <td nowrap=''>
                <emit source='license-module-features'
                  >&_.name;:&nbsp;&_.value;<delimiter><br /></delimiter></emit>
                <else>&nbsp;</else>
              </td>
            </tr>
          </emit>
        </tbody>
      </table>
      <emit source='license-warnings' rowinfo='var.warnings'></emit>
      <if variable='var.warnings > 0'>
        <h3><div class='notify warn inline'>Warnings</div></h3>
        <table class='nice'>
          <thead>
            <tr>
              <th>Type</th>
              <th>Warning</th>
              <th>Time</th>
            </tr>
          </thead>
          <emit source='license-warnings'>
            <tr>
              <td nowrap=''>&_.type;</td>
              <td>&_.msg;</td>
              <td><date type='iso' unix-time='&_.time;'/></td>
            </tr>
          </emit>
        </table>
      </if>
    </license>
  </if>
  <input type=hidden name=action value='licensestatus.pike' />
  <p>
    <cf-ok-button href='./'/>
  </p>
";
  return txt;
}
