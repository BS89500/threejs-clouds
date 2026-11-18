varying vec3 vLocalPosition;

void main() {
    vLocalPosition = position; // Pass raw local position to fragment shader
    vec4 worldPosition = modelMatrix * vec4(position, 1.0);
    gl_Position = projectionMatrix * viewMatrix * worldPosition;
}