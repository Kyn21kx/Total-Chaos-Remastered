#import "Basic";
#import "Math";
#import "GL";
#import "String";

#load "freetype_bindings.jai";

#scope_module

MAX_TEXT_CHARS :: 4096;
MAX_GLYPHS :: 256;
TEXTURE_SIZE :: 512;

GlyphInfo :: struct {
    texture_x: float;
    texture_y: float;
    width: float;
    height: float;
    offset_x: float;
    offset_y: float;
    advance: float;
    loaded: bool;
}

Font_Renderer :: struct {
    ft_library: FT_Library;
    ft_face: *FT_FaceRec;
    font_texture: u32;
    glyphs: [MAX_GLYPHS] GlyphInfo;
    next_page_x: s32;
    next_page_y: s32;
    line_height: s32;
    font_loaded: bool;
}

TextVertex :: struct {
    x, y: float;
    u, v: float;
    r, g, b, a: float;
}

text_buffer: [MAX_TEXT_CHARS * 6] TextVertex;
next_text_vertex := 0;

init_font_renderer :: (renderer: *Font_Renderer) {
    if FT_Init_FreeType(*renderer.ft_library) != 0 {
        print("Failed to initialize FreeType\n");
        return;
    }
    
    glGenTextures(1, *renderer.font_texture);
    glBindTexture(GL_TEXTURE_2D, renderer.font_texture);
    
    pixels := alloc(TEXTURE_SIZE * TEXTURE_SIZE);
    memset(pixels, 0, TEXTURE_SIZE * TEXTURE_SIZE);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, TEXTURE_SIZE, TEXTURE_SIZE, 0, GL_RED, GL_UNSIGNED_BYTE, pixels);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    free(pixels);
    
    renderer.next_page_x = 2;
    renderer.next_page_y = 2;
    renderer.line_height = 0;
    
    for i : 0..MAX_GLYPHS-1 {
        renderer.glyphs[i].loaded = false;
    }
}

shutdown_font_renderer :: (renderer: *Font_Renderer) {
    if renderer.font_texture {
        glDeleteTextures(1, *renderer.font_texture);
    }
    if renderer.ft_face {
        FT_Done_Face(cast(FT_Face) renderer.ft_face);
    }
    if renderer.ft_library {
        FT_Done_FreeType(renderer.ft_library);
    }
}

load_font_file :: (renderer: *Font_Renderer, path: string) -> bool {
    if renderer.ft_face {
        FT_Done_Face(cast(FT_Face) renderer.ft_face);
    }
    
    cpath := to_c_string(path);
    face: FT_Face;
    if FT_New_Face(renderer.ft_library, cpath, 0, *face) != 0 {
        print("Failed to load font: %\n", path);
        return false;
    }
    
    renderer.ft_face = cast(*FT_FaceRec) face;
    
    FT_Set_Pixel_Sizes(cast(FT_Face) renderer.ft_face, 0, 48);
    
    renderer.line_height = cast(s32) (renderer.ft_face.height / 64);
    renderer.font_loaded = true;
    
    return true;
}

render_glyph :: (renderer: *Font_Renderer, char_code: u32) {
    if char_code >= cast(u32) MAX_GLYPHS return;
    if !renderer.ft_face return;
    
    glyph_index := FT_Get_Char_Index(cast(FT_Face) renderer.ft_face, char_code);
    if FT_Load_Glyph(cast(FT_Face) renderer.ft_face, glyph_index, FT_LOAD_RENDER) != 0 {
        return;
    }
    
    ft_glyph := renderer.ft_face.glyph;
    if !ft_glyph return;
    bitmap := ft_glyph.bitmap;
    
    if bitmap.width == 0 || bitmap.rows == 0 return;
    
    glyph := *renderer.glyphs[char_code];
    glyph.width = cast(float) bitmap.width;
    glyph.height = cast(float) bitmap.rows;
    glyph.offset_x = cast(float) ft_glyph.bitmap_left;
    glyph.offset_y = cast(float) ft_glyph.bitmap_top;
    glyph.advance = cast(float) (ft_glyph.advance.x / 64);
    
    if renderer.next_page_x + cast(s32) bitmap.width + 2 >= TEXTURE_SIZE {
        renderer.next_page_x = 2;
        renderer.next_page_y += renderer.line_height + 2;
    }
    
    if renderer.next_page_y + cast(s32) bitmap.rows + 2 >= TEXTURE_SIZE {
        return;
    }
    
    glyph.texture_x = cast(float) renderer.next_page_x;
    glyph.texture_y = cast(float) renderer.next_page_y;
    
    glBindTexture(GL_TEXTURE_2D, renderer.font_texture);
    
    row_pitch := bitmap.pitch;
    line_size := bitmap.width;
    
    row_data := bitmap.buffer;
    for row: 0..cast(u32) bitmap.rows - 1 {
        glTexSubImage2D(
            GL_TEXTURE_2D, 0,
            renderer.next_page_x, 
            renderer.next_page_y + cast(s32) row,
            bitmap.width, 1,
            GL_RED, GL_UNSIGNED_BYTE,
            row_data
        );
        row_data += row_pitch;
    }
    
    renderer.next_page_x += cast(s32) (bitmap.width + 2);
    
    glyph.loaded = true;
}

ensure_glyph :: (renderer: *Font_Renderer, char_code: u32) {
    if char_code >= cast(u32) MAX_GLYPHS return;
    if !renderer.glyphs[char_code].loaded && renderer.font_loaded {
        render_glyph(renderer, char_code);
    }
}

get_glyph :: (renderer: *Font_Renderer, char_code: u32) -> *GlyphInfo {
    if char_code >= cast(u32) MAX_GLYPHS return null;
    return *renderer.glyphs[char_code];
}

get_char_width :: (renderer: *Font_Renderer, char_code: u32, font_size: s32) -> float {
    scale := cast(float) font_size / 48.0;
    glyph := get_glyph(renderer, char_code);
    if !glyph return cast(float) font_size * 0.5;
    return glyph.advance * scale;
}

get_string_width :: (renderer: *Font_Renderer, text: string, font_size: s32) -> s32 {
    total_width: float;
    i := 0;
    while i < text.count {
        cp, len := utf8_next_code_point(text, i);
        total_width += get_char_width(renderer, cp, font_size);
        i += len;
    }
    return cast(s32) total_width;
}

utf8_next_code_point :: (str: string, index: int) -> cp: u32, len: int {
    if index >= str.count return 0, 0;
    
    b := cast(u32) str.data[index];
    
    if b < 0x80 {
        return b, 1;
    } else if b < 0xC0 {
        return 0xFFFD, 1;
    } else if b < 0xE0 {
        if index + 1 >= str.count return 0xFFFD, 1;
        cp := ((b & 0x1F) << 6) | (cast(u32) str.data[index + 1] & 0x3F);
        return cp, 2;
    } else if b < 0xF0 {
        if index + 2 >= str.count return 0xFFFD, 1;
        cp := ((b & 0x0F) << 12) | ((cast(u32) str.data[index + 1] & 0x3F) << 6) | (cast(u32) str.data[index + 2] & 0x3F);
        return cp, 3;
    } else {
        if index + 3 >= str.count return 0xFFFD, 1;
        cp := ((b & 0x07) << 18) | ((cast(u32) str.data[index + 1] & 0x3F) << 12) | ((cast(u32) str.data[index + 2] & 0x3F) << 6) | (cast(u32) str.data[index + 3] & 0x3F);
        return cp, 4;
    }
}

queue_text :: (renderer: *Font_Renderer, text: string, x: float, y: float, color: Vector4, font_size: s32) {
    if !renderer.font_loaded return;
    
    scale := cast(float) font_size / 48.0;
    
    cursor_x := x;
    cursor_y := y;
    
    i := 0;
    while i < text.count {
        cp, len := utf8_next_code_point(text, i);
        
        if cp == 0 || cp == 0xFFFD {
            i += max(1, len);
            continue;
        }
        
        if cp == #char "\n" {
            cursor_x = x;
            cursor_y += cast(float) renderer.line_height * scale;
            i += len;
            continue;
        }
        
        ensure_glyph(renderer, cp);
        glyph := get_glyph(renderer, cp);
        
        if glyph && glyph.loaded {
            if next_text_vertex + 6 > MAX_TEXT_CHARS * 6 {
                i += len;
                continue;
            }
            
            tex_x0 := glyph.texture_x / cast(float) TEXTURE_SIZE;
            tex_y0 := glyph.texture_y / cast(float) TEXTURE_SIZE;
            tex_x1 := (glyph.texture_x + glyph.width) / cast(float) TEXTURE_SIZE;
            tex_y1 := (glyph.texture_y + glyph.height) / cast(float) TEXTURE_SIZE;
            
            quad_x0 := cursor_x + glyph.offset_x * scale;
            quad_y0 := cursor_y - glyph.offset_y * scale;
            quad_x1 := quad_x0 + glyph.width * scale;
            quad_y1 := quad_y0 + glyph.height * scale;
            
            verts := *text_buffer[next_text_vertex];
            verts[0] = TextVertex.{quad_x0, quad_y0, tex_x0, tex_y1, color.x, color.y, color.z, color.w};
            verts[1] = TextVertex.{quad_x1, quad_y0, tex_x1, tex_y1, color.x, color.y, color.z, color.w};
            verts[2] = TextVertex.{quad_x0, quad_y1, tex_x0, tex_y0, color.x, color.y, color.z, color.w};
            verts[3] = TextVertex.{quad_x1, quad_y0, tex_x1, tex_y1, color.x, color.y, color.z, color.w};
            verts[4] = TextVertex.{quad_x1, quad_y1, tex_x1, tex_y0, color.x, color.y, color.z, color.w};
            verts[5] = TextVertex.{quad_x0, quad_y1, tex_x0, tex_y0, color.x, color.y, color.z, color.w};
            
            next_text_vertex += 6;
        }
        
        cursor_x += glyph.advance * scale;
        i += len;
    }
}

flush_text :: (renderer: *Renderer) {
    if next_text_vertex == 0 return;
    
    vao: u32;
    vbo: u32;
    glGenVertexArrays(1, *vao);
    glGenBuffers(1, *vbo);
    
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, next_text_vertex * size_of(TextVertex), text_buffer.data, GL_DYNAMIC_DRAW);
    
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, size_of(TextVertex), cast(*void) 0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(TextVertex), cast(*void) 8);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, size_of(TextVertex), cast(*void) 16);
    glEnableVertexAttribArray(2);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, renderer.font_renderer.font_texture);
    
    shader := get_text_shader();
    glUseProgram(shader);
    
    glUniform1i(glGetUniformLocation(shader, "textTexture"), 0);
    
    proj := ortho_projection(cast(float) renderer.width, cast(float) renderer.height);
    glUniformMatrix4fv(glGetUniformLocation(shader, "projection"), 1, GL_TRUE, proj.floats.data);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glDrawArrays(GL_TRIANGLES, 0, cast(GLsizei) next_text_vertex);
    
    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);
    glDisableVertexAttribArray(2);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    glDeleteBuffers(1, *vbo);
    glDeleteVertexArrays(1, *vao);
    
    next_text_vertex = 0;
}
