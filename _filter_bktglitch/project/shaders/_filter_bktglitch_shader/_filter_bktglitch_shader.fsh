//////////////////////////////////
//                              //
//   bktGlitch 1.3.2            //
//    Written by Jan Vorisek    //
//    Adapted by Nik the cat    //
//     @blokatt | blokatt.net   //
//      jan@blokatt.net         //
//       31/01/2021             //
//                              //
//     "Here we go again."      //
//							 	//
//////////////////////////////////

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
#define gltexture2D texture2D

// MAIN CONTROLLER UNIFORMS
uniform float intensity;       // overall effect intensity, 0-1 (no upper limit)
uniform float gm_pTime;            // global timer variable (PASSED BY GM)
uniform vec2  gm_pSurfaceDimensions;      // screen resolution (PASSED BY GM)
uniform float rngSeed;         // seed offset (changes configuration around)
uniform sampler2D noiseTexture;// noise texture sampler
uniform vec2 noiseTextureDimensions;// noise texture sampler size in pixels (PASSED BY GM)

// noise width and height are passed by GM, it'd be rude to not use this information
// instead of hard-coding, right?
#define NOISE_TEXTURE_PIXEL_COUNT (noiseTextureDimensions.x * noiseTextureDimensions.y)

//TUNING
uniform float lineSpeed;       // line speed
uniform float lineDrift;       // horizontal line drifting
uniform float lineResolution;  // line resolution
uniform float lineVertShift;   // wave phase offset of horizontal lines
uniform float lineShift;       // horizontal shift
uniform float jumbleness;      // amount of "block" glitchiness
uniform float jumbleResolution;// resolution of blocks
uniform float jumbleShift;     // texture shift by blocks  
uniform float jumbleSpeed;     // speed of block variation
uniform float dispersion;      // color channel horizontal dispersion
uniform float channelShift;    // horizontal RGB shift
uniform float noiseLevel;      // level of noise
uniform float shakiness;       // horizontal shakiness
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

void main()
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
