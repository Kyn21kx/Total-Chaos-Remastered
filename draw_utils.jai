#import "Basic";
Simp :: #import "Simp";
GL :: #import "GL";


scene_fbo      : u32;
scene_texture  : u32;
post_shader    : u32;
quad_vao       : u32;
quad_vbo       : u32;


DrawCircle :: (center: Vector2, radius: float, color: Vector4, segments: int = 32) {
    Simp.set_shader_for_color(true);

    step := (2.0 * PI) / cast(float) segments;

    for i : 0..segments-1 {
        angle0 := step * cast(float) i;
        angle1 := step * cast(float) (i + 1);

        x0 := center.x + cos(angle0) * radius;
        y0 := center.y + sin(angle0) * radius;
        x1 := center.x + cos(angle1) * radius;
        y1 := center.y + sin(angle1) * radius;

        // Draw triangle: center + two points on circumference
        Simp.immediate_triangle(
            .{center.x, center.y, 0},
            .{x0, y0, 0},
            .{x1, y1, 0},
            color,
            color,
            color
        );
    }
}

DrawRect :: (position: Vector2, size: Vector2, color: Vector4) {
    Simp.set_shader_for_color();
    Simp.immediate_quad(position.x, position.y, position.x + size.x, position.y + size.y, color);
}

DrawTriangle :: (center: Vector2, size: float, angle: float, color: Vector4) {
    // Define the three points of the triangle relative to center
    // Pointing up by default
    Simp.set_shader_for_color(true);
    local_points := Vector2.[
        .{0.0,          size},        // top
        .{-size * 0.75, -size * 0.5}, // bottom left
        .{ size * 0.75, -size * 0.5}, // bottom right
    ];

    // Rotate each point around the center
    ca := cos(angle);
    sa := sin(angle);

    rotated : [3] Vector2;
    for i : 0..2 {
        p := local_points[i];
        rotated[i] = .{
            center.x + p.x * ca - p.y * sa,
            center.y + p.x * sa + p.y * ca,
        };
    }

    Simp.immediate_triangle(
        .{rotated[0].x, rotated[0].y, 0},
        .{rotated[1].x, rotated[1].y, 0},
        .{rotated[2].x, rotated[2].y, 0},
        color, color, color
    );
}


setup_fullscreen_quad :: () {
    // Two triangles = triangle strip (positions + UVs)
    vertices : [16]float = .[
        -1.0, -1.0,  0.0, 0.0,
         1.0, -1.0,  1.0, 0.0,
        -1.0,  1.0,  0.0, 1.0,
         1.0,  1.0,  1.0, 1.0,
    ];

    GL.glGenVertexArrays(1, *quad_vao);
    GL.glGenBuffers(1, *quad_vbo);

    GL.glBindVertexArray(quad_vao);
    GL.glBindBuffer(GL.GL_ARRAY_BUFFER, quad_vbo);
    GL.glBufferData(GL.GL_ARRAY_BUFFER, size_of(float) * 16, *vertices, GL.GL_STATIC_DRAW);

    // position
    GL.glVertexAttribPointer(0, 2, GL.GL_FLOAT, false, 4 * size_of(float), null);
    GL.glEnableVertexAttribArray(0);
    // texcoord
    offset := cast(u64)(2 * size_of(float));
    GL.glVertexAttribPointer(1, 2, GL.GL_FLOAT, false, 4 * size_of(float), *offset);
    GL.glEnableVertexAttribArray(1);

    GL.glBindBuffer(GL.GL_ARRAY_BUFFER, 0);
    GL.glBindVertexArray(0);
}

create_post_process_resources :: () {
    // Texture (render target)
    GL.glGenTextures(1, *scene_texture);
    GL.glBindTexture(GL.GL_TEXTURE_2D, scene_texture);
    GL.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_RGBA, cast(u32)width, cast(u32)height, 0, GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, null);
    GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR);
    GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR);

    // FBO
    GL.glGenFramebuffers(1, *scene_fbo);
    GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, scene_fbo);
    GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, scene_fbo);
    GL.glFramebufferTexture2D(GL.GL_FRAMEBUFFER, GL.GL_COLOR_ATTACHMENT0, GL.GL_TEXTURE_2D, scene_texture, 0);
    // (you can add depth if you ever need it)

    if (GL.glCheckFramebufferStatus(GL.GL_FRAMEBUFFER) != GL.GL_FRAMEBUFFER_COMPLETE) {
        print("ERROR: Framebuffer not complete!\n");
    }

    GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, 0);

    post_shader = create_post_shader();
    setup_fullscreen_quad();
}
create_post_shader :: () -> u32 {
    vertex_src :: #string END
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoords;
out vec2 TexCoords;
void main() {
    TexCoords = aTexCoords;
    gl_Position = vec4(aPos, 0.0, 1.0);
}
END

    frag_src :: #string END
#version 330 core
in vec2 TexCoords;
uniform sampler2D screenTexture;
out vec4 FragColor;
void main() {
    FragColor = texture(screenTexture, TexCoords);
    // ←←← YOUR POST EFFECTS GO HERE (e.g. for bloom testing)
    // FragColor.rgb *= 1.5;          // simple brightness boost
    // FragColor.rgb = max(FragColor.rgb - 0.8, 0.0); // bright-pass test
    // FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
END

    vshader := GL.glCreateShader(GL.GL_VERTEX_SHADER);
    
    vertexCStr := temp_c_string(vertex_src);
    vertexLength := cast(s32)vertex_src.count;
    GL.glShaderSource(vshader, 1, *vertexCStr, *vertexLength);
    GL.glCompileShader(vshader);
    // (add GL.get_shader_iv error checking if you want robustness)

    fshader := GL.glCreateShader(GL.GL_FRAGMENT_SHADER);
    fragmentCStr := temp_c_string(frag_src);
    fragmentLength := cast(s32)frag_src.count;
    GL.glShaderSource(fshader, 1, *fragmentCStr, *fragmentLength);
    GL.glCompileShader(fshader);

    program := GL.glCreateProgram();
    GL.glAttachShader(program, vshader);
    GL.glAttachShader(program, fshader);
    GL.glLinkProgram(program);

    GL.glDeleteShader(vshader);
    GL.glDeleteShader(fshader);
    return program;
}

render_post_process :: () {
    GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, 0);

    GL.glUseProgram(post_shader);
    GL.glActiveTexture(GL.GL_TEXTURE0);
    GL.glBindTexture(GL.GL_TEXTURE_2D, scene_texture);
    // uniform is bound to texture unit 0 by default, but we can set it explicitly:
    // location := GL.get_uniform_location(post_shader, "screenTexture");
    // GL.uniform_1i(location, 0);

    GL.glBindVertexArray(quad_vao);
    GL.glDrawArrays(GL.GL_TRIANGLE_STRIP, 0, 4);

    GL.glGenVertexArrays(0, null);
    GL.glUseProgram(0); // optional cleanup
}
