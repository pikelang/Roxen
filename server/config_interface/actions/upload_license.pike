/*
 * $Id$
 */

#include <roxen.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

string name= LOCALE(180, "Upload license...");
string doc = LOCALE(168, "Upload a new Roxen license file.");


int enabled()
{
  return License.is_active(getenv("ROXEN_LICENSEDIR") || "../license");
}

mixed parse( RequestID id )
{
  string txt = #"
  <font size='+1'><b>Upload License</b></font>
  <p />
  <set variable='var.show-form' value='true'/>
  <if variable='form.file'>
    <if variable='form.file = ?*'>
      <set variable='var.show-form' value='false'/>
      <set variable='var.filename'
      	><get-post-filename filename='&form.file..filename;'
      			    js-filename='&form.fixedfilename;'/></set>
      <if variable='form.Overwrite..x'>
      	<set variable='var.ok' value='ok'/>
      </if>
      <elseif license='&var.filename;'>
      	<input type='hidden' name='action' value='&form.action;'/>
      	<input type='hidden' name='file' value='&form.file;'/>
      	<input type='hidden' name='file.filename' value='&var.filename;'/>
      	<imgs src='&usr.err-2;' alt='#' />
      	Warning: The license file <b>&var.filename;</b> does already exists.
      	Do you want to overwrite the file?<br /><br />
      	<submit-gbutton>Overwrite</submit-gbutton>
	<cf-cancel href='./?class="+action+#"&amp;&usr.set-wiz-id;'/>
      </elseif>
      <else>
      	<set variable='var.ok' value='ok'/>
      </else>
      <if variable='var.ok'>
      	<upload-license filename='&var.filename;' from='form.file'/>
      	License uploaded successfully.
      	<br /><br />
      	<cf-ok/>
      </if>
    </if>
    <else>
      <p><imgs src='&usr.err-3;' alt='#' /> This is not a valid file.</p>
    </else>
  </if>

  <if variable='var.show-form = true'>
    <input type='hidden' name='action' value='&form.action;'/>
    Select local file to upload: <br />
    <input type='file' name='file' size='40'/>
    <input type='hidden' name='fixedfilename' value='' />
    <submit-gbutton name='ok' width='75' align='center'
      onClick=\"this.form.fixedfilename.value=this.form.file.value.replace(/\\\\/g,'\\\\\\\\')\"><translate id=\"201\">OK</translate></submit-gbutton>
    <br /><br />

    <cf-cancel href='./?class="+action+#"&amp;&usr.set-wiz-id;'/>
  </if>
";
  
  return txt;
}
