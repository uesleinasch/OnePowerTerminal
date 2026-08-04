#version 330
uniform sampler2D tex;
uniform float opacity;
in vec2 texcoord;
out vec4 fragColor;

// --- CONFIGURAÇÃO ---
// Intensidade do Grão: 0.0 = Nenhum, 0.05 = Subtil, 0.1 = Papel Grosso
#define GRAIN_INTENSITY 0.07

// Função de Ruído Pseudo-Aleatório (Hash)
float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
    // 1. Amostragem da Cor Original
    vec4 color = texture(tex, texcoord);

    // 2. Conversão de Luminância (Grayscale)
    float gray = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

    // 3. Geração de Ruído Estático
    float noise = (rand(texcoord) - 0.5) * GRAIN_INTENSITY;

    // 4. Aplicação do Ruído
    float paper_gray = gray + noise;

    // 5. Reconstrução do Pixel
    vec4 final_color = vec4(vec3(paper_gray), color.a);

    // 6. Aplicação da Opacidade
    final_color *= opacity;

    fragColor = final_color;
}