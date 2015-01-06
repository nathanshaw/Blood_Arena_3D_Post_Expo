varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform sampler2D texture;

uniform vec2 resolution;
uniform float time;
uniform vec2 mouse;

uniform float alpha;

uniform float floor;
uniform float ceil;

uniform float mix;
uniform float periods;
uniform float rate;

uniform float border;
uniform float circle_radius;

uniform float cover; //.6
uniform float sharpness; //.003

uniform vec3 color;

vec3 clouds(vec2 ipos, float icover, float isharpness);
float noise( in vec2 x );
float fbm( vec2 p );
float hash( float n );

//float getSmallestNormal
//float getLargestNormal

void main(void)
{
	vec3 filter;

	vec2 pos = ( gl_FragCoord.xy / resolution.xy );
	vec2 m = ( mouse.xy / resolution.xy );

	float d = distance(m, pos);

	//color junk
	float r = sin(d * 3.14 * (periods/circle_radius * 2.0) - (time * rate) );
	float di = cos(d * 3.14 * (periods/circle_radius * 2.0) - (time * rate) );
    
    float noise = cos(pos.x*1000.0+cos(pos.y*489.9+time+pos.x*50.0)*1450.0);

	//could use cosine to "discard" as well
	
    //mix with clouds
	vec3 dry = texture2D(texture, vertTexCoord.st).xyz * vertColor.xyz;
    vec3 cloudcolor = clouds(pos, cover, sharpness);
    vec3 mixed = mix(dry, cloudcolor, mix);

    //white in resulting mix.
	float norm = distance(mixed.xyz, vec3(0.0));
	
	if (norm < floor) { discard; }
	else if (norm >= ceil) { norm = 1.0; }

	if ( d > circle_radius )
	{
		filter = vec3(norm) * vec3(noise);
	}
	
	else if ( d < (circle_radius - border))
	{
        filter = vec3(norm) * vec3(noise);
	}

	else if (r >= .5)
	{
		filter = vec3(norm) * vec3(noise) * color;
	}
    
    else
    {
        discard;
    }
    

	gl_FragColor = vec4(filter, alpha);

}

vec3 clouds(vec2 ipos, float icover, float isharpness)
{
// Wind - Used to animate the clouds
	vec2 wind_vec = vec2(0.001 + time*0.01, 0.003 + time * 0.01);
	
	// Set up domain
	vec2 q = ipos;
	vec2 p = -1.0 + 5.0 * q + wind_vec;
	
	// Fix aspect ratio
	p.x *= resolution.x / resolution.y;
    
	
	// Create noise using fBm
	float f = fbm( 1.0*p );
	
	float c = f - (1.0 - icover);
	if ( c < 0.0 )
		c = 0.0;
	
	f = 1.0 - (pow(isharpness, c));
	
    
	return vec3(f);
}

float noise( in vec2 x )
{
	vec2 p = floor(x);
	vec2 f = fract(x);
    f = f*f*(3.0-2.0*f);
    float n = p.x + p.y*57.0;
    float res = mix(mix( hash(n+  0.0), hash(n+  1.0),f.x), mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y);
    return res;
}

float fbm( vec2 p )
{
    float f = 0.0;
    f += 0.50000*noise( p ); p = p*2.02;
    f += 0.25000*noise( p+time ); p = p*2.03;
    f += 0.12500*noise( p+time/2.0 ); p = p*2.01;
    f += 0.06250*noise( p); p = p*2.04;
    f += 0.03125*noise( p );
    return f/0.984375;
}

float hash( float n )
{
	return fract(sin(n)*43758.5453);
}

/*
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
*/