function renderLink(text, action, file, base, target)
{
  return "&nbsp;<a href='"+base+"?action="+action+"' "+
    (target != undefined?" target='"+target+"' ":"")+
    "onMouseOver=\"setStatus('"+text+"');\" "+
    "onMouseOut=\"setStatus('');\""+
    ">"+text+"</a><br>\n";
}

function renderStyle(id)
{
  return "<style>#"+id+
    " {position:absolute; left:0; top:0; visibility:hidden}</style>\n";
}

function renderIcon(id, icon, text)
{
  return "<div id='"+id+"'><img border=0 src='"+icon+"' alt=''>"+text+"</div>";
}

function renderPopup(id, file, base, actions)
{
  var r =
    "<div id='"+id+"' onMouseOut=\"hidePopup('"+id+"');\">\n<tab"+
    "le border=1 cellspacing=1 cellpadding=3 bgcolor='bbbbbb'><tr><td>\n"+
    "<b>"+file+"</b><hr>\n"+
    "<i>View</i><br>\n";
  if(actions>>0&1)
    r += renderLink("View", "view.pike", file, base, "RoxenSBView");
  if(actions>>1&1)
    r += renderLink("View source", "view_source.pike",file,base,"RoxenSBView");
  if(actions>>2&1)
    r += renderLink("Log", "log.pike", file, base);
  if(actions>>3&1)
    r += renderLink("Annotate", "annotate.pike", file, base);
  r += "<i>Edit</i><br>\n";
  if(actions>>4&1)
    r += renderLink("Edit", "edit_file, base.pike", file, base);
  if(actions>>5&1)
    r += renderLink("Edit new file", "create_file.pike", file, base);
  if(actions>>6&1)
    r += renderLink("Edit metadata", "edit_metadata.pike", file, base);
  if(actions>>7&1)
    r += renderLink("Download", "download.pike", file, base);
  if(actions>>8&1)
    r += renderLink("Upload file", "upload_file.pike", file, base);
  if(actions>>9&1)
    r += renderLink("Upload new file", "upload_new_file.pike", file, base);
  r += "<i>File</i><br>\n";
  if(actions>>10&1)
    r += renderLink("Create directory", "create_dir.pike", file, base);
  if(actions>>11&1)
    r += renderLink("Copy", "copy.pike", file, base);
  if(actions>>12&1)
    r += renderLink("Move", "move.pike", file, base);
  if(actions>>13&1)
    r += renderLink("Delete", "delete.pike", file, base);
  r += "<i>Version Control</i><br>\n";
  if(actions>>14&1)
    r += renderLink("Discard your changes", "discard.pike", file, base);
  if(actions>>15&1)
    r += renderLink("Update", "update.pike", file, base);
  if(actions>>16&1)
    r += renderLink("Commit", "commit.pike", file, base);
  if(actions>>17&1)
    r += renderLink("Join", "join.pike", file, base);
  r += "<i>Access Control</i><br>\n";
  if(actions>>18&1)
    r += renderLink("Add protection point", "app_ppoint.pike", file, base);
  if(actions>>19&1)
    r += renderLink("Remove protection point", "remove_ppoint.pike",file,base);
  r += "<i>Undelete</i><br>\n";
  if(actions>>20&1)
    r += renderLink("Enter normal mode","enter_normal_mode.pike",file, base);
  if(actions>>21&1)
    r +=renderLink("Enter undelete mode","enter_undelete_mode.pike",file,base);
  if(actions>>22&1)
    r += renderLink("Undelete", "undelete.pike", file, base);
  r += "</td></tr></table></div>\n";
  return r;
}

function doDrop() {
  if(modifiers & Event.CONTROL_MASK) {
    if(!(src_actions>>11&1)) {
      alert("Can not copy this file/directory");
      return;
    }
    if(confirm('Copy '+src_path+' to '+dest_name+'.'))
      window.location = (src_url+'?&action=copy.pike'+
			 '&destdir='+dest_name+
			 '&destname='+src_name);
    return;
  }
  if(!(src_actions>>12&1)) {
    alert("Can not move this file/directory, try to commit it first");
    return;
  }
  if(confirm('Move '+src_path+' to '+dest_name+'.'))
    window.location = (src_url+'?&action=move.pike'+
		       '&destdir='+dest_name+
		       '&destname='+src_name);
}
