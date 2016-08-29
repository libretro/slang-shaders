//hacky clamp fix
vec2 bordertest = (vTexCoord);
vec3 res = texture(Source, vTexCoord).rgb;
if ( bordertest.x > 0.0001 && bordertest.x < 0.9999 && bordertest.y > 0.0001 && bordertest.y < 0.9999)
res.rgb = res.rgb;
else
res.rgb = vec3(0.0);