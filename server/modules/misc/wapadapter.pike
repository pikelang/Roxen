// This is a roxen module. Copyright © 2000, Roxen IS.
//

inherit "module";

constant thread_safe = 1;
constant cvs_version = "$Id: wapadapter.pike,v 1.1 2000/02/19 02:17:42 nilsson Exp $";

constant module_type = MODULE_FIRST|MODULE_FILTER;
constant module_name = "WAP Adapter";
constant module_doc  = "Improves supports flags and variables as well as "
  "doing a better job finding MIME types than the content type module for WAP clients.";

RequestID first_try(RequestID id) {
  if(!id->request_headers->accept) id->request_headers->accept="";

  if(has_value(id->request_headers->accept,"image/x-wap.wbmp") ||
     has_value(id->request_headers->accept,"image/vnd.wap.wbmp")) id->supports->wbmp0=1;

  if(id->supports["wap1.1"] || id->supports["wap1.0"]) return id;

  if(has_value(id->request_headers->accept,"text/vnd.wap.wml") ||
     has_value(id->request_headers->accept,"application/vnd.wap.wml")) id->supports["wap1.1"]=1;
  if(has_value(id->request_headers->accept,"text/x-wap.wml")) id->supports["wap1.0"]=1;

  if(id->supports->unknown) {
    id->supports["wap1.1"]=1;
    id->supports->wbmp0=1;
  }

  return id;
}

mapping filter(mapping result, RequestID id) {
  if(result->type=="text/vnd.wap.wml" &&
     !id->supports["wap1.1"] &&
     id->supports["wap1.0"]) {
    result->type="text/x-wap.wml";
  }

  if(result->type=="image/vnd.wap.wbmp" &&
     !id->supports["wap1.1"] &&
     id->supports["wap1.0"]) {
    result->type="image/x-wap.wbmp";
  }

  return result;
}
