#include "GameMaker.fxh"

// compile as:
// fxc /Ges /Vi /T fx_2_0 /Fo _filter_glitch.fxb _filter_glitch.fx

// Attributes
attribute vec3 in_Position;
attribute vec3 in_Normal; // (usually unused)
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

// aka GLSL vars:
// GLSL ES has only one render target, so one element in the array.
// if we had more than one target, we'd increment this array's size.
static vec4 gl_Color[1];
static vec4 gl_Position;

varying vec2 v_vTexcoord;
varying vec4 v_vColour;

// registers s0 and c0 are reserved by GameMaker.fxh and are passed by the IDE
// they should NOT be used.

#define DELTA 0.00001
#define TAU 6.28318530718
#define RND (TAU+DELTA+123.457*0.42069+0.100+0.200)

// the original shader did current_time * 0.06
// but this gm_pTime thing seems sketchy
// please play around with it if you have issues.
//#define TIMEMUL (0.06)
//#define TIMEMUL   (1.00)

// MAIN CONTROLLER UNIFORMS
uniform float intensity : register(c1);       // overall effect intensity, 0-1 (no upper limit)
uniform float gm_pTime  : register(c2);            // global timer variable
uniform vec2  gm_pSurfaceDimensions : register(c3);      // screen resolution
uniform float rngSeed : register(c4);         // seed offset (changes configuration around)
uniform sampler2D noiseTexture : register(s1);// noise texture sampler
uniform vec2 noiseTextureDimensions : register(c5);// noise texture sampler size in pixels

// noise width and height are passed by GM, it'd be rude to not use this information
// instead of hard-coding, right?
#define NOISE_TEXTURE_PIXEL_COUNT (noiseTextureDimensions.x * noiseTextureDimensions.y)

//TUNING
uniform float lineSpeed : register(c6);       // line speed
uniform float lineDrift : register(c7);       // horizontal line drifting
uniform float lineResolution : register(c8);  // line resolution
uniform float lineVertShift : register(c9);   // wave phase offset of horizontal lines
uniform float lineShift : register(c10);       // horizontal shift
uniform float jumbleness : register(c11);      // amount of "block" glitchiness
uniform float jumbleResolution : register(c12);// resolution of blocks
uniform float jumbleShift : register(c13);     // texture shift by blocks  
uniform float jumbleSpeed : register(c14);     // speed of block variation
uniform float dispersion : register(c15);      // color channel horizontal dispersion
uniform float channelShift : register(c16);    // horizontal RGB shift
uniform float noiseLevel : register(c17);      // level of noise
uniform float shakiness : register(c18);       // horizontal shakiness
uniform float timemul : register(c19); // time multiplier factor (0-1)
//

vec4 extractRed(vec4 col){
    return vec4(col.x, 0., 0., col.w);
}

vec4 extractGreen(vec4 col){
    return vec4(0., col.y, 0., col.w);
}

vec4 extractBlue(vec4 col){
    return vec4(0., 0., col.z, col.w);
}

// Replacement for the mirror address mode, hopefully nobody needs filtering.
vec2 mirror(vec2 v) {
    return abs((fract((v * 0.5) + 0.5) * 2.0) - 1.0);
}

vec2 downsample(vec2 v, vec2 res) {    
	// Division by zero protected by uniform getters.
    return floor(v * res) / res;
}

// Fetches four random values from an RGBA noise texture
vec4 whiteNoise(vec2 coord, vec2 texelOffset) {
	vec2 offset = downsample(vec2(rngSeed * noiseTextureDimensions.x, rngSeed) + texelOffset, noiseTextureDimensions);
    vec2 ratio = gm_pSurfaceDimensions / noiseTextureDimensions;
    return gltexture2D(noiseTexture, (coord * ratio) + offset); 
}

// Fetch noise texture texel based on single offset in the [0-1] range
vec4 random(float dataOffset) {
	vec2 halfTexelSize = vec2((0.5 / noiseTextureDimensions.x), (0.5 / noiseTextureDimensions.y));
	float offset = rngSeed + dataOffset;    
    return gltexture2D(noiseTexture, vec2(offset * noiseTextureDimensions.x, offset) + halfTexelSize); 
}

// Jumble coord generation
vec2 jumble(vec2 coord){
	// Static branch.
	if ((jumbleShift * jumbleness * jumbleResolution) < DELTA) {
		return vec2(0.0, 0.0);
	}
		
    vec2 gridCoords = (coord * jumbleResolution) / (noiseTextureDimensions.x * 0.0245);
	float jumbleTime = mod(floor(gm_pTime * timemul * 0.02 * jumbleSpeed), NOISE_TEXTURE_PIXEL_COUNT);
	vec2 offset = random(jumbleTime / NOISE_TEXTURE_PIXEL_COUNT).ga * jumbleResolution;
    vec4 cellRandomValues = whiteNoise(gridCoords, vec2(jumbleResolution * -10.0, jumbleResolution * -10.0) + offset);
    return (cellRandomValues.ra - 0.5) * jumbleShift * floor(min(0.99999, cellRandomValues.b) + jumbleness);
}

// Horizontal line offset generation
float lineOffset(vec2 coord) {
	// Static branch.
	if (lineShift < DELTA) {
		return 0.0;
	}
	
    // Wave offsets
    vec2 waveHeights = vec2(50.0 * lineResolution, 25.0 * lineResolution);    
    vec4 lineRandom = whiteNoise(downsample(v_vTexcoord.yy, waveHeights), vec2(0.0, 0.0));
    float driftTime = v_vTexcoord.y * gm_pSurfaceDimensions.y * 2.778;
    
    // XY: big waves, ZW: drift waves
    vec4 waveTimes = (vec4(downsample(lineRandom.ra * TAU, waveHeights) * 80.0, driftTime + 2.0, (driftTime * 0.1) + 1.0) + (gm_pTime * timemul * lineSpeed)) + (lineVertShift * TAU);
    vec4 waveLineOffsets = vec4(sin(waveTimes.x), cos(waveTimes.y), sin(waveTimes.z), cos(waveTimes.w));
    waveLineOffsets.xy *= ((whiteNoise(waveTimes.xy, vec2(0.0, 0.0)).yz - 0.5) * shakiness) + 1.0;
    waveLineOffsets.zw *= lineDrift;
    return dot(waveLineOffsets, vec4(1.0, 1.0, 1.0, 1.0));
}

void Vgl_main()
{
    vec4 object_space_pos = vec4(in_Position.x, in_Position.y, in_Position.z, 1.0);
    // in IDE shaders we don't have gm_Matrices, but we have an MVPTransform uniform
    // which is the matrix we need to multiply by.
    gl_Position = mul(object_space_pos, MVPTransform);
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
}

void Pgl_main()
{
    vec3 randomValues = vec3(gm_pTime*RND+1.0/gm_pSurfaceDimensions.x*0.33333, gm_pTime*RND*RND+123.5682*54823.65547, gm_pTime+1337.228*420.69+RND);
    randomValues.x = mod(randomValues.x, 1.0);
    randomValues.y = mod(randomValues.y, 1.0);
    randomValues.z = mod(randomValues.z, 1.0);
    
    // Sample random high-frequency noise
    vec4 randomHiFreq = whiteNoise(v_vTexcoord, randomValues.xy);
    
    // Apply line offsets
    vec2 offsetCoords = v_vTexcoord;
    offsetCoords.x += ((((2.0 * randomValues.z) - 1.0) * shakiness * lineSpeed) + lineOffset(offsetCoords)) * lineShift * intensity;
    
    // Apply jumbles
    offsetCoords += jumble(offsetCoords) * intensity * intensity * 0.25;
        
    // Channel split
    vec2 shiftFactors = (channelShift + (randomHiFreq.rg * dispersion)) * intensity;
    vec4 outColour;
	
	// Static branch.
    if (((channelShift + dispersion) * intensity) < DELTA) {
		outColour = gltexture2D(gm_BaseTexture, mirror(offsetCoords));
	} else {
		outColour = extractRed(gltexture2D(gm_BaseTexture, mirror(offsetCoords + vec2(shiftFactors.r, 0.0)))) + extractBlue(gltexture2D(gm_BaseTexture, mirror(offsetCoords + vec2(-shiftFactors.g, 0.0)))) + extractGreen(gltexture2D(gm_BaseTexture, mirror(offsetCoords)));
	}
	
    // xyzw|rgba
    // ywz
    // Add noise	
    outColour.xyz *= (vec3(.55, .5, .4) * randomHiFreq.ywz * intensity * noiseLevel) + 1.0;
       
    gl_FragColor = v_vColour * outColour;
}

VS_OUTPUT Vmain(VS_INPUT input)
{
    in_Position = input._in_Position;
    in_Normal = input._in_Normal;
    in_Colour = input._in_Colour;
    in_TextureCoord = input._in_TextureCoord;

    Vgl_main();

    VS_OUTPUT output;
    output.gl_Position.x = gl_Position.x;
    output.gl_Position.y = gl_Position.y;
    output.gl_Position.z = gl_Position.z;
    output.gl_Position.w = gl_Position.w;
    output.v0 = v_vColour;
    output.v1 = v_vTexcoord;

    return output;
}

PS_OUTPUT Pmain(VS_OUTPUT input)
{
    v_vColour = input.v0;
    v_vTexcoord = input.v1.xy;

    Pgl_main();

    PS_OUTPUT output;
    output.gl_Color0 = gl_Color[0];
    return output;
}

technique _filter_glitchShader
{
    pass MainPass1
    {
        VertexShader = compile vs_3_0 Vmain();
        PixelShader  = compile ps_3_0 Pmain();
    }
}
