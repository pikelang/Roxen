<tmplblock tag=h1>
  <cset variable=shadow></cset>
  <if match='$$h1_shadow$$ is 1'><cset
    variable=shadow>shadow='60,1'</cset></if>
  <formoutput quote='%'>
    <p><br>
    <div align=$$h1_align$$>
      <gtext fg=$$h1_color$$ bg=$$bg_color$$ afont='$$h1_font$$' %shadow%
      scale=$$h1_size$$>$h1$</gtext>
    </div>
  </formoutput>
</tmplblock>

<tmplblock tag=h2>
  <cset variable=shadow></cset>
  <if match='$$h2_shadow$$ is 1'><cset
    variable=shadow>shadow='60,1'</cset></if>
  <formoutput quote='%'>
    <p>
    <div align=$$h2_align$$>
      <gtext fg=$$h2_color$$ bg=$$bg_color$$ afont='$$h2_font$$' %shadow%
        scale=$$h2_size$$>$h2$</gtext>
    </div>
  </formoutput>
</tmplblock>