<tmplblock tag=h1>
  <cset variable=shadow></cset>
  <if match='$$h1_shadow$$ is 1'><cset
    variable=shadow>shadow=60,1</cset></if>
  <formoutput quote='%'>
    <p><br>
    <div align=$$h1_align$$>
      <gtext align=center fg=$$h1_dingbat_color$$ bg=$$bg_color$$
        nfont='zapf dingbats'
        scale=$$h1_dingbat_size$$ alt=''>$$h1_dingbat$$</gtext>
      <gtext align=center fg=$$h1_color$$ bg=$$bg_color$$ nfont='$$h1_font$$'
        $$h1_font_style$$ %shadow% scale=$$h1_size$$>$h1$</gtext>
    </div>
  </formoutput>
</tmplblock>

<tmplblock tag=h2>
  <cset variable=shadow></cset>
  <if match='$$h2_shadow$$ is 1'><cset
    variable=shadow>shadow=60,1</cset></if>
  <formoutput quote='%'>
    <p>
    <div align=$$h2_align$$>
      <gtext align=center fg=$$h2_dingbat_color$$ bg=$$bg_color$$
        nfont='zapf dingbats'
        scale=$$h1_dingbat_size$$ alt=''>$$h2_dingbat$$</gtext>
      <gtext align=center fg=$$h2_color$$ bg=$$bg_color$$ nfont='$$h2_font$$'
        $$h2_font_style$$ %shadow% scale=$$h2_size$$>$h2$</gtext>
    </div>
  </formoutput>
</tmplblock>