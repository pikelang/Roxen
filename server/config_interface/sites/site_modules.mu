<ul class="site-nav site{{#js}} js{{/js}}">
  {{ #buttons_first }}
    <li class='button first {{ class_name }}'>
      <a href="{{ href }}">{{ name }}</a>
    </li>
  {{ /buttons_first }}

  {{ #module_groups }}
    <li class="module-group{{^fold}} unfolded{{/fold}}">
      <a href="{{ url }}">{{ name }} <span class="nmodules">({{ nmodules }})</span></a>
      <ul class="{{ #fold }}folded{{ /fold }}">
        {{ #modules }}
          <li class='{{#selected}}selected{{/selected}}{{#deprecated}} deprecated{{/deprecated}}'>
            <a href="{{ url }}">{{ name }}</a>
          </li>
        {{ /modules }}
      </ul>
    </li>
  {{ /module_groups }}

  {{ #buttons_last }}
    <li class='button last {{ class_name }}'>
      <a href="{{ href }}">{{ name }}</a>
    </li>
  {{ /buttons_last }}
</ul>
