#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D texture;

varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform float time;
uniform vec2 resolution;

uniform float bars;
uniform float bars2;
uniform float rate;
uniform float rate2;
uniform float thresh1;
uniform float thresh2;
uniform vec3 color1;
uniform vec3 color2;
uniform float alpha;


void main( void ) {
    
	vec2 position = ( gl_FragCoord.xy / resolution.xy );
    
	float x = sin((position.x + (time * rate)) * bars * 3.14); //.5 so x + y = 1.0
    float y = sin((position.x + (time * rate2)) * bars2 * 3.14);
    
    vec3 wet;
	
	if (x < thresh1 && y < thresh2)
	{
		discard
	}
	else
	{
        wet = mix(color1, color2, .5); //dunno, at x = 1 y = 1 I want .5. at 1, 0, I want 0, at 0, 1 I want 1
	}
	
	gl_FragColor = vec4(vec3(wet),alpha);
	
}