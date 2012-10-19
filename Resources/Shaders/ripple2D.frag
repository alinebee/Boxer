uniform float time;
uniform vec2 rippleOrigin;
uniform vec2 rubyContentSize;
uniform vec2 rubyInputSize;
uniform sampler2D rubyTexture;
uniform float rippleHeight;

const float maxDistance = 0.05; //The ripples will extend to 10% of the total view area
const float speedFactor = 16.0;
const float rippleQuantity = 200.0;

void main(void)
{
	vec2 normalizedCoords = gl_TexCoord[0].xy * rubyTextureSize;
    
    float distanceFromOrigin = distance(normalizedCoords, rippleOrigin * (rubyInputSize / rubyTextureSize));

    float distanceCoefficient = min(1.0, max(0.0, maxDistance - distanceFromOrigin));
    //Make the strength of the ripples taper off as they reach the edge
    float dampedHeight = rippleHeight * distanceCoefficient;

    float scaledTime = time * speedFactor;
    float distortion = cos((distanceFromOrigin * rippleQuantity) - scaledTime);

    vec2 sourcePixel = normalizedCoords + (distortion * dampedHeight);
    
    gl_FragColor = texture2D(rubyTexture, sourcePixel);
}