#version 450 core // Minimal GL version support expected from the GPU

struct LightSource {
    vec3 position;
    vec3 color;
    float intensity;
    mat4 depthMVP;
    int isActive;
};

const int MAX_LIGHTS = 10;

uniform int number_of_lights;

uniform LightSource lightSource [ MAX_LIGHTS ];


struct ShadowMap {
    sampler2D depthMap;
    int lightIndex;
};

uniform ShadowMap shadowMap [ MAX_LIGHTS ];


struct Material {
    vec3 albedo;
    float shininess;
};

uniform Material material;


in vec3 fPosition; // Shader input, linearly interpolated by default from the previous stage (here the vertex shader)
in vec3 fPositionWorldSpace;
in vec3 fNormal;
in vec2 fTexCoord;

out vec4 colorResponse; // Shader output: the color response attached to this fragment


uniform mat4 projectionMat, modelViewMat, normalMat;



float pi = 3.1415927;

vec4 fPosLightSpace;
float shadow;

float ShadowCalculation(vec4 fragPos, int index_light, float bias)
{
    vec3 projCoords = fragPos.xyz / fragPos.w;
    projCoords = projCoords * 0.5 + 0.5;
    float closestDepth = texture(shadowMap[index_light].depthMap, projCoords.xy).r;
    float currentDepth = projCoords.z;
    float shadow = currentDepth - bias < closestDepth ? 1.0 : 0.0;
    
    return shadow;
}


void main() {
    vec3 n = normalize(fNormal);

    // Linear barycentric interpolation does not preserve unit vectors
    vec3 wo = normalize (-fPosition); // unit vector pointing to the camera
    vec3 radiance = vec3(0,0,0);

    for (int index_light = 0; index_light < number_of_lights; index_light++){
        if( dot( n , wo ) >= 0.0 ) 
        {
            if( lightSource[index_light].isActive == 1 ) // WE ONLY CONSIDER LIGHTS THAT ARE SWITCHED ON
            { 
                vec3 wi = normalize ( vec3((modelViewMat * vec4(lightSource[index_light].position,1)).xyz) - fPosition ); // unit vector pointing to the light source (change if you use several light sources!!!)
                if( dot( wi , n ) >= 0.0 ) // WE ONLY CONSIDER LIGHTS THAT ARE ON THE RIGHT HEMISPHERE (side of the tangent plane)
                { 
                    vec3 wh = normalize( wi + wo ); // half vector (if wi changes, wo should change as well)
                    vec3 Li = lightSource[index_light].color * lightSource[index_light].intensity;

                    // Shadow
                    fPosLightSpace = lightSource[index_light].depthMVP * vec4(fPositionWorldSpace, 1.0);
                    float bias = max(0.05 * (1.0 - dot(n, -wi)), 0.005);
                    shadow = ShadowCalculation(fPosLightSpace, index_light, bias);

                    radiance = radiance + 
                            (
                            Li // light color
                            * material.albedo
                            * ( max(dot(n,wi),0.0) + pow(max(dot(n,wh),0.0),material.shininess) )
                            * shadow // Shadow 
                            )
                            ;
                }
            }
        }
    }
    

    colorResponse = vec4 ( (radiance) , 1.0); // Building an RGBA value from an RGB one.
}




