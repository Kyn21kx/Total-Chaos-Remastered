#import "Basic";
#import "Math";
#import "String";
#import "SDL";

#load "renderer_opengl.jai";
#load "renderer_shader.jai";
#load "renderer_text.jai";

#scope_export

Renderer :: struct {
    window: *SDL_Window;
    gl_context: SDL_GLContext;
    width: s32;
    height: s32;
    
    triangle_vao: u32;
    triangle_vbo: u32;
    triangle_count: int;
    
    font_renderer: Font_Renderer;
}

init :: (width: s32, height: s32, title: string) -> *Renderer {
    result := New(Renderer);
    result.width = width;
    result.height = height;
    
    if SDL_Init(xx SDL_INIT_VIDEO) < 0 {
        print("SDL_Init failed: %\n", to_string(SDL_GetError()));
        return null;
    }
    
    SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(.SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(.SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(.SDL_GL_DEPTH_SIZE, 24);
    
    ctitle := temp_c_string(title);
    result.window = SDL_CreateWindow(
        ctitle,
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        width,
        height,
        SDL_WindowFlags.SDL_WINDOW_OPENGL | SDL_WindowFlags.SDL_WINDOW_SHOWN
    );
    
    if !result.window {
        print("SDL_CreateWindow failed: %\n", to_string(SDL_GetError()));
        SDL_Quit();
        return null;
    }
    
    result.gl_context = SDL_GL_CreateContext(result.window);
    if !result.gl_context {
        print("SDL_GL_CreateContext failed: %\n", to_string(SDL_GetError()));
        SDL_DestroyWindow(result.window);
        SDL_Quit();
        return null;
    }
    
    SDL_GL_MakeCurrent(result.window, result.gl_context);
    
    gl_load(*gl, SDL_GL_GetProcAddress);
    using gl;
    
    major, minor: s32;
    glGetIntegerv(GL_MAJOR_VERSION, *major);
    glGetIntegerv(GL_MINOR_VERSION, *minor);
    print("GL Version: %.% \n", major, minor);
    
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    
    init_shaders();
    init_opengl(result);
    init_font_renderer(*result.font_renderer);
    init_font_renderer(*result.font_renderer);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glViewport(0, 0, xx width, xx height);
    
    return result;
}

shutdown :: (renderer: *Renderer) {
    if !renderer return;
    
    shutdown_font_renderer(*renderer.font_renderer);
    shutdown_opengl(renderer);
    shutdown_shaders();
    
    if renderer.gl_context {
        SDL_GL_DeleteContext(renderer.gl_context);
    }
    if renderer.window {
        SDL_DestroyWindow(renderer.window);
    }
    SDL_Quit();
}

begin_frame :: (renderer: *Renderer) {
    renderer.triangle_count = 0;
    glClearColor(0.2, 0.3, 0.3, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
}

end_frame :: (renderer: *Renderer) {
    flush_triangles(renderer);
    flush_text(renderer);
    SDL_GL_SwapWindow(renderer.window);
}

clear :: (renderer: *Renderer, r: float, g: float, b: float, a: float) {
    glClearColor(r, g, b, a);
    glClear(GL_COLOR_BUFFER_BIT);
}

immediate_triangle :: (renderer: *Renderer, x0: float, y0: float, x1: float, y1: float, x2: float, y2: float, c0: Vector4, c1: Vector4, c2: Vector4) {
    add_triangle_vertex(renderer, x0, y0, c0);
    add_triangle_vertex(renderer, x1, y1, c1);
    add_triangle_vertex(renderer, x2, y2, c2);
}

draw_circle :: (renderer: *Renderer, center_x: float, center_y: float, radius: float, color: Vector4, segments: int = 32) {
    step := (2.0 * PI) / cast(float) segments;
    
    for i : 0..segments-1 {
        angle0 := step * cast(float) i;
        angle1 := step * cast(float) (i + 1);
        
        x0 := center_x + cos(angle0) * radius;
        y0 := center_y + sin(angle0) * radius;
        x1 := center_x + cos(angle1) * radius;
        y1 := center_y + sin(angle1) * radius;
        
        immediate_triangle(
            renderer,
            center_x, center_y,
            x0, y0,
            x1, y1,
            color, color, color
        );
    }
}

draw_rect :: (renderer: *Renderer, x0: float, y0: float, x1: float, y1: float, color: Vector4) {
    immediate_triangle(
        renderer,
        x0, y0,
        x1, y0,
        x0, y1,
        color, color, color
    );
    
    immediate_triangle(
        renderer,
        x1, y0,
        x1, y1,
        x0, y1,
        color, color, color
    );
}

draw_text :: (renderer: *Renderer, text: string, x: float, y: float, color: Vector4, font_size: s32 = 24) {
    queue_text(*renderer.font_renderer, text, x, y, color, font_size);
}

get_text_width :: (renderer: *Renderer, text: string, font_size: s32 = 24) -> s32 {
    return get_string_width(*renderer.font_renderer, text, font_size);
}

load_font :: (renderer: *Renderer, path: string) -> bool {
    return load_font_file(*renderer.font_renderer, path);
}
