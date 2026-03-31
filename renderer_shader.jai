#import "Basic";
#import "Math";
#import "GL";

#scope_module

color_shader_program: u32;
color_vertex_shader: u32;
color_fragment_shader: u32;
text_shader_program: u32;
text_vertex_shader: u32;
text_fragment_shader: u32;

VERTEX_SHADER :: #string GLSL
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec4 aColor;

out vec4 vColor;

uniform mat4 projection;

void main()
{
    gl_Position = projection * vec4(aPos, 1.0);
    vColor = aColor;
}
GLSL

FRAGMENT_SHADER :: #string GLSL
#version 330 core
in vec4 vColor;

out vec4 FragColor;

void main()
{
    FragColor = vColor;
}
GLSL

TEXT_VERTEX_SHADER :: #string GLSL
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec4 aColor;

out vec2 vTexCoord;
out vec4 vColor;

uniform mat4 projection;

void main()
{
    gl_Position = projection * vec4(aPos, 0.0, 1.0);
    vTexCoord = aTexCoord;
    vColor = aColor;
}
GLSL

TEXT_FRAGMENT_SHADER :: #string GLSL
#version 330 core
in vec2 vTexCoord;
in vec4 vColor;

out vec4 FragColor;

uniform sampler2D textTexture;

void main()
{
    float alpha = texture(textTexture, vTexCoord).r;
    FragColor = vec4(vColor.rgb, vColor.a * alpha);
}
GLSL

compile_shader :: (shader_type: u32, source: string) -> u32 {
    shader := glCreateShader(shader_type);
    src := to_c_string(source);
    glShaderSource(shader, 1, *src, null);
    glCompileShader(shader);
    
    success: s32;
    glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
    if !success {
        info_log: [512] u8;
        glGetShaderInfoLog(shader, 512, null, info_log.data);
        print("Shader compile error: %\n", to_string(info_log.data));
        return 0;
    }
    return shader;
}

create_program :: (vs: u32, fs: u32) -> u32 {
    program := glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);
    
    success: s32;
    glGetProgramiv(program, GL_LINK_STATUS, *success);
    if !success {
        info_log: [512] u8;
        glGetProgramInfoLog(program, 512, null, info_log.data);
        print("Program link error: %\n", to_string(info_log.data));
        return 0;
    }
    return program;
}

init_shaders :: () {
    color_vertex_shader = compile_shader(GL_VERTEX_SHADER, VERTEX_SHADER);
    color_fragment_shader = compile_shader(GL_FRAGMENT_SHADER, FRAGMENT_SHADER);
    color_shader_program = create_program(color_vertex_shader, color_fragment_shader);
    
    text_vertex_shader = compile_shader(GL_VERTEX_SHADER, TEXT_VERTEX_SHADER);
    text_fragment_shader = compile_shader(GL_FRAGMENT_SHADER, TEXT_FRAGMENT_SHADER);
    text_shader_program = create_program(text_vertex_shader, text_fragment_shader);
}

shutdown_shaders :: () {
    if color_shader_program {
        glDeleteProgram(color_shader_program);
    }
    if color_vertex_shader {
        glDeleteShader(color_vertex_shader);
    }
    if color_fragment_shader {
        glDeleteShader(color_fragment_shader);
    }
    if text_shader_program {
        glDeleteProgram(text_shader_program);
    }
    if text_vertex_shader {
        glDeleteShader(text_vertex_shader);
    }
    if text_fragment_shader {
        glDeleteShader(text_fragment_shader);
    }
}

get_color_shader :: () -> u32 { return color_shader_program; }
get_text_shader :: () -> u32 { return text_shader_program; }
