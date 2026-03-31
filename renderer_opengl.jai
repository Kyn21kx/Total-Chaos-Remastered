#import "Basic";
#import "Math";
#import "GL";

#scope_module

MAX_TRIANGLES :: 16384;
VERTICES_PER_TRIANGLE :: 3;
FLOATS_PER_VERTEX :: 7;

VertexData :: struct {
    x, y, z: float;
    r, g, b, a: float;
}

triangle_buffer: [MAX_TRIANGLES * VERTICES_PER_TRIANGLE * FLOATS_PER_VERTEX] float;
next_vertex := 0;

init_opengl :: (renderer: *Renderer) {
    glGenVertexArrays(1, *renderer.triangle_vao);
    glGenBuffers(1, *renderer.triangle_vbo);
    
    glBindVertexArray(renderer.triangle_vao);
    glBindBuffer(GL_ARRAY_BUFFER, renderer.triangle_vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(triangle_buffer)), triangle_buffer.data, GL_DYNAMIC_DRAW);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, FLOATS_PER_VERTEX * 4, cast(*void) 0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, FLOATS_PER_VERTEX * 4, cast(*void) (3 * 4));
    glEnableVertexAttribArray(1);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
}

shutdown_opengl :: (renderer: *Renderer) {
    if renderer.triangle_vbo {
        glDeleteBuffers(1, *renderer.triangle_vbo);
    }
    if renderer.triangle_vao {
        glDeleteVertexArrays(1, *renderer.triangle_vao);
    }
}

add_triangle_vertex :: (renderer: *Renderer, x: float, y: float, color: Vector4) {
    idx := next_vertex;
    triangle_buffer[idx * FLOATS_PER_VERTEX + 0] = x;
    triangle_buffer[idx * FLOATS_PER_VERTEX + 1] = y;
    triangle_buffer[idx * FLOATS_PER_VERTEX + 2] = 0.0;
    triangle_buffer[idx * FLOATS_PER_VERTEX + 3] = color.x;
    triangle_buffer[idx * FLOATS_PER_VERTEX + 4] = color.y;
    triangle_buffer[idx * FLOATS_PER_VERTEX + 5] = color.z;
    triangle_buffer[idx * FLOATS_PER_VERTEX + 6] = color.w;
    next_vertex += 1;
    renderer.triangle_count = next_vertex / 3;
}

flush_triangles :: (renderer: *Renderer) {
    if renderer.triangle_count == 0 return;
    
    glBindVertexArray(renderer.triangle_vao);
    glBindBuffer(GL_ARRAY_BUFFER, renderer.triangle_vbo);
    
    vertex_count := renderer.triangle_count * VERTICES_PER_TRIANGLE;
    data_size := vertex_count * FLOATS_PER_VERTEX * 4;
    glBufferSubData(GL_ARRAY_BUFFER, 0, data_size, triangle_buffer.data);
    
    shader := get_color_shader();
    glUseProgram(shader);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    proj := ortho_projection(cast(float) renderer.width, cast(float) renderer.height);
    proj_loc := glGetUniformLocation(shader, "projection");
    glUniformMatrix4fv(proj_loc, 1, GL_TRUE, proj.floats.data);
    
    glDrawArrays(GL_TRIANGLES, 0, cast(GLsizei) vertex_count);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    
    next_vertex = 0;
    renderer.triangle_count = 0;
}

ortho_projection :: (width: float, height: float) -> Matrix4 {
    return orthographic_projection_matrix(0.0, width, 0.0, height, -1.0, 1.0);
}
