<h1>Global module page</h1>

<awizard>
  <page>
     <button page=add_module title='Add module'>
     <button page=delete_module title='Delete module'>
  </page>
  <page name=add_module>
    <insert file=add_module.inc>
    <button page=final_add_module title=" OK ">
  </page>

  <page name=final_add_module>
    <pike>
     foreach( id->variables->_add_new_modules/"\0", string module )
       id->misc->current_configuration->enable_module( module );
     return "";
    </pike>
    <goto href="../">
  </page>
</awizard>

