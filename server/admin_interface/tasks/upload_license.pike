/*
 * $Id: upload_license.pike,v 1.7 2002/09/26 22:34:16 nilsson Exp $
 */

constant task = "maintenance";
constant name = "Upload license";
constant doc  = "Upload a new roxen license file.";

mixed parse( RequestID id )
{
  string txt = #"
  <h1>Upload License</h1>
  <if variable='form.file'>
    <set variable='var.filename'
      ><get-post-filename filename='&form.file..filename;'
                          js-filename='&form.fixedfilename;'/></set>
    <if variable='form.Overwrite..x'>
      <set variable='var.ok' value='ok'/>
    </if>
    <elseif license='&var.filename;'>
      <input type='hidden' name='task' value='&form.task;'/>
      <input type='hidden' name='file' value='&form.file;'/>
      <input type='hidden' name='file.filename' value='&var.filename;'/>
      Warning the license file <b>&var.filename;</b> does already exists.
      Do you want to overwrite the file? <br />
      <submit-gbutton>Overwrite</submit-gbutton>
      &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      <cf-cancel/>
    </elseif>
    <else>
      <set variable='var.ok' value='ok'/>
    </else>
    <if variable='var.ok'>
      <upload-license filename='&var.filename;' from='form.file'/>
      License uploaded successfully. <cf-ok/>
    </if>
  </if>
  <else>
    <input type='hidden' name='task' value='&form.task;'/>
    Select local file to upload: <br />
    <input type='file' name='file'/>
    <input type='hidden' name='fixedfilename' value='' />
    <submit-gbutton name='ok'
      onClick=\"this.form.fixedfilename.value=this.form.file.value.replace(/\\\\/g,'\\\\\\\\')\">Ok</submit-gbutton>

    <cf-cancel/>
  </else>
";
  
  return txt;
}
