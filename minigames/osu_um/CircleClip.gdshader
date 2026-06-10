shader_type canvas_item;

uniform sampler2D texture_sampler : hint_default_white;
uniform float circle_radius : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    if (dist > circle_radius) {
        discard;
    }
    
    COLOR = texture(texture_sampler, UV);
}
