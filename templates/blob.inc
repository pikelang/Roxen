<define tag=blob>
  <rimage>
    <layer>
      <load file=/img/corner.pnm>
      <save to=hej>
      <solid replace color=&color1;>
    </layer>

    <layer width=&size; height=&size;>
      <solid channel=image color=&color2;>
      <restore channel=mask from=hej>
      <rotate degree=45 channel=image>
    </layer>
  </rimage>
</define>