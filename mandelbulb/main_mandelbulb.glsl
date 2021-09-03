#iChannel0 "file://buffer_mandelbulb.glsl"

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec4 data = texelFetch(iChannel0, ivec2(fragCoord),0);
    fragColor = vec4(data.rgb/data.w,1.0);
}