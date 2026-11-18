precision highp float;

// Use the local position from the vertex shader to avoid stretching
varying vec3 vLocalPosition; 

uniform vec3 uCameraPosition;
uniform float uTime;
uniform vec3 uSunPosition;
uniform mat4 uInverseModelMatrix; // NEW: Needed to transform camera and sun into local space

// --- Noise Functions ---
float hash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
                   mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
                   mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
    float sum = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 3; i++) {
        sum += amp * noise(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    return sum;
}

// --- Ray-Box Intersection ---
vec2 rayBoxIntersection(vec3 rayOrigin, vec3 rayDir, vec3 boxMin, vec3 boxMax) {
    vec3 invDir = 1.0 / rayDir;
    vec3 t0 = (boxMin - rayOrigin) * invDir;
    vec3 t1 = (boxMax - rayOrigin) * invDir;
    vec3 tMin = min(t0, t1);
    vec3 tMax = max(t0, t1);
    float tNear = max(max(tMin.x, tMin.y), tMin.z);
    float tFar = min(min(tMax.x, tMax.y), tMax.z);
    return vec2(tNear, tFar);
}

// --- Lighting ---
float sampleLight(vec3 position, vec3 sunDir) {
    float lightDensity = 0.0;
    vec3 currentPos = position;
    float stepSize = 1.0; 
    
    for(int j = 0; j < 4; j++) {
        currentPos += sunDir * stepSize;
        vec3 p = currentPos * 0.3 + vec3(uTime * 0.02, 0.0, 0.0);
        float density = smoothstep(0.3, 0.7, fbm(p));
        if (density > 0.0) {
            lightDensity += density;
        }
    }
    return exp(-lightDensity * 0.4);
}

// --- Main Loop ---
void main() {
    // 1. Transform Camera and Sun into LOCAL SPACE
    vec3 localCameraPos = (uInverseModelMatrix * vec4(uCameraPosition, 1.0)).xyz;
    // Direction vectors have w=0.0 so they ignore translation
    vec3 localSunDir = normalize((uInverseModelMatrix * vec4(uSunPosition, 0.0)).xyz); 

    // 2. Set Ray Origin and Direction in local space
    vec3 rayDir = normalize(vLocalPosition - localCameraPos);
    vec3 rayPos = localCameraPos;

    // 3. Define Box Bounds (Must match half your THREE.BoxGeometry dimensions)
    // If your BoxGeometry is (40, 10, 40), bounds are -20 to 20, -5 to 5.
    vec3 boxMin = vec3(-20.0, -5.0, -20.0);
    vec3 boxMax = vec3(20.0, 5.0, 20.0);

    vec2 bounds = rayBoxIntersection(rayPos, rayDir, boxMin, boxMax);
    float tNear = bounds.x;
    float tFar = bounds.y;

    if (tNear > tFar || tFar < 0.0) {
        discard;
    }

    float tCurrent = max(0.0, tNear);
    vec3 entryPoint = rayPos + rayDir * tCurrent;
    vec3 exitPoint = rayPos + rayDir * tFar;
    
    float rayLength = length(exitPoint - entryPoint);
    int steps = 32;
    float stepSize = rayLength / float(steps);

    vec3 currentPos = entryPoint;
    float totalDensity = 0.0;
    vec3 accumulatedColor = vec3(0.0);

    for(int i = 0; i < 32; i++) {
        vec3 p = currentPos * 0.3 + vec3(uTime * 0.02, 0.0, 0.0);
        float cloudShape = fbm(p);
        float density = smoothstep(0.2, 0.4, cloudShape);
        
        if (density > 0.0) {
            float sunLight = sampleLight(currentPos, localSunDir);
            vec3 lightColor = mix(vec3(0.5, 0.6, 0.7), vec3(1.0, 0.95, 0.9), sunLight);
            
            float alpha = density * (stepSize * 0.2);
            accumulatedColor += lightColor * alpha * (1.0 - totalDensity);
            totalDensity += alpha;
            
            if (totalDensity >= 1.0) break;
        }
        
        currentPos += rayDir * stepSize;
    }

    gl_FragColor = vec4(accumulatedColor, clamp(totalDensity, 0.0, 1.0));
}