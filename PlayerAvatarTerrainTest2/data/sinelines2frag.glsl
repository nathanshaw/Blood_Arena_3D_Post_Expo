#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D texture;

varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform float time;
uniform vec2 resolution;

uniform float bars1;
uniform float bars2;
uniform float rate1;
uniform float rate2;
uniform float thresh1;
uniform float thresh2;
uniform float alpha;

uniform vec3 color;


void main( void ) {
    
	vec2 position = ( gl_FragCoord.xy / resolution.xy );
    
	float r = sin((position.x + (time * rate1)) * bars1 * 3.14);
    float b = sin((position.x + (time * rate2)) * bars2 * 3.14);
    
    vec3 wet;
	
	if (r < thresh1 && b < thresh2)
	{
		discard;
	}
	else
	{
        wet = vec3(r, 0.0, b);
	}
	
	gl_FragColor = vec4(wet * color,alpha);
	
}