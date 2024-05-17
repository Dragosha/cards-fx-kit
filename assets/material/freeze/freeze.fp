varying mediump vec2 var_texcoord0;
varying lowp vec4 var_color;

uniform lowp sampler2D texture_sampler;
uniform lowp sampler2D noise;

uniform mediump vec4 glow_color;

void main()
{
    vec4 color = texture2D(texture_sampler, var_texcoord0.xy);

    if(var_color.w < 1.0) {
        float noise_value = texture2D(noise, var_texcoord0.xy*2.).r * 0.999;
        float is_visible = var_color.w - noise_value;
        // if (is_visible < 0.0) discard;

        float is_glowing = smoothstep(var_color.z, .01, is_visible);
        vec3 glow = is_glowing * glow_color.rgb + vec3(clamp((1.0-var_color.w) * color.r, 0.0, 1.0));
        color.rgb = color.rgb + glow * color.a;
    }
    gl_FragColor = color;
}
