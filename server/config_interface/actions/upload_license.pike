/*
 * $Id: upload_license.pike,v 1.1 2002/03/06 16:21:23 wellhard Exp $
 */

#include <roxen.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

string name= LOCALE(0, "Upload license");
string doc = LOCALE(0, "Upload a new roxen license file.");


mixed parse( RequestID id )
{
  string txt = #"
  <h1>Upload License</h1>
  <if variable='form.file'>
    <if variable='form.Overwirte..x'>
      <set variable='var.ok' value='ok'/>
    </if>
    <elseif license='&form.file..filename;'>
      <input type='hidden' name='action' value='&form.action;'/>
      <input type='hidden' name='file' value='&form.file;'/>
      <input type='hidden' name='file.filename' value='&form.file..filename;'/>
      Warning the license file &form.file..filename; does already exists.
      Do you want to overwrite the file? <br />
      <submit-gbutton>Overwirte</submit-gbutton>
      &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      <cf-cancel/>
    </elseif>
    <else>
      <set variable='var.ok' value='ok'/>
    </else>
    <if variable='var.ok'>
      <upload-license filename='&form.file..filename;' from='form.file'/>
      License uploaded successfuly. <cf-ok/>
    </if>
  </if>
  <else>
    <input type='hidden' name='action' value='&form.action;'/>
    Select local file to upload: <br />
    <input type='file' name='file'/>
    <submit-gbutton name='ok'>Ok</submit-gbutton>
    <cf-cancel/>
  </else>
";
  
  return txt;
}
