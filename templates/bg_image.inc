<if not match='$$bg_image$$ is '>
  <cset variable=bg_image preparse>background=<rimage-id>
    <layer>
      <load file=$$bg_image$$>
      <save to=hej>
      <solid replace color=$$bg_image_color_2$$>
    </layer>

    <layer width=128 height=128>
      <solid channel=image color=$$bg_image_color$$>
      <restore channel=mask from=hej>
    </layer>

  </rimage-id></cset>
</if>

<if not match='$$text_bg_image$$ is '>
  <cset variable=text_bg_image preparse>background=<rimage-id>
    <layer>
      <load file=$$text_bg_image$$>
      <save to=hej>
      <solid replace color=$$text_bg_image_color_2$$>
    </layer>

    <layer width=128 height=128>
      <solid channel=image color=$$text_bg_image_color$$>
      <restore channel=mask from=hej>
    </layer>

  </rimage-id></cset>
</if>
