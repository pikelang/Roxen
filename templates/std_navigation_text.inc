<cset variable=shadow></cset>
<if match='$$nav_shadow$$ is 1'><cset variable=shadow>shadow='60,1'</cset></if>
<formoutput quote=¤>
  <textstyle $$nav_align$$ scale=$$nav_size$$ font='$$nav_font$$' xspacing=5 yspacing=5>

  <boxstyle middle text bg=$$nav_bg_color$$ fg=$$nav_text_color$$
    alpha=255 ¤shadow¤>
  <boxstyle middle text selected bg=$$nav_bg_color_sel$$
    fg=$$nav_text_color_sel$$ alpha=255 ¤shadow¤>
  <boxstyle middle text mouseover bg=$$nav_bg_color_mouse$$
    fg=$$nav_text_color_mouse$$ alpha=255 ¤shadow¤>
</formoutput>