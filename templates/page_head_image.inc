<if not match='$$page_head_image$$ is '>
  <cset variable=page_head_image preparse><rimage-id>
    <layer>
      <load file=$$page_head_image$$>
      <save to=hej>
      <solid replace color=$$page_head_image_bg_color$$>
    </layer>

    <layer width=450 height=50>
      <solid channel=image color=$$page_head_image_fg_color$$>
      <restore channel=mask from=hej>
    </layer>

  </rimage-id></cset>
  <formoutput quote=¥>
    <img src=¥page_head_image¥ width=100% height=50 alt=""></formoutput></if><else>
    <img src="/internal-roxen-unit" width=1 height=1></else>