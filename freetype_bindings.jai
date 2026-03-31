#import "Basic";

#scope_module

FT_Library :: *void;
FT_Face :: *void;

FT_Error :: s32;
FT_Long :: s64;
FT_ULong :: u64;
FT_UInt :: u32;
FT_Int32 :: s32;
FT_Short :: s16;
FT_UShort :: u16;
FT_Pos :: s64;
FT_Fixed :: s64;

FT_LOAD_RENDER :: 0x0004;

FT_Bitmap :: struct {
    rows: u32;
    width: u32;
    pitch: s32;
    buffer: *u8;
    num_grays: u16;
    pixel_mode: u8;
    palette_mode: u8;
    palette: *void;
}

FT_Glyph_Metrics :: struct {
    width: FT_Pos;
    height: FT_Pos;
    horiBearingX: FT_Pos;
    horiBearingY: FT_Pos;
    horiAdvance: FT_Pos;
    vertBearingX: FT_Pos;
    vertBearingY: FT_Pos;
    vertAdvance: FT_Pos;
}

FT_Vector :: struct {
    x: FT_Pos;
    y: FT_Pos;
}

FT_Generic :: struct {
    data: *void;
    finalizer: FT_Generic_Finalizer;
}

FT_Generic_Finalizer :: #type (object: *void) #c_call;

FT_Glyph_Format :: enum u32 {
    FT_GLYPH_FORMAT_NONE      :: 0;
    FT_GLYPH_FORMAT_COMPOSITE :: 1;
    FT_GLYPH_FORMAT_BITMAP    :: 2;
    FT_GLYPH_FORMAT_OUTLINE   :: 3;
    FT_GLYPH_FORMAT_PLOTTER   :: 4;
}

FT_Outline :: struct {
    n_contours: s16;
    n_points: s16;
    points: *FT_Vector;
    tags: *u8;
    contours: *s16;
    flags: s32;
}

FT_GlyphSlot :: struct {
    library: FT_Library;
    face: FT_Face;
    next: *FT_GlyphSlot;
    reserved: u32;
    generic: FT_Generic;
    
    metrics: FT_Glyph_Metrics;
    linearHoriAdvance: FT_Fixed;
    linearVertAdvance: FT_Fixed;
    advance: FT_Vector;
    
    format: FT_Glyph_Format;
    
    bitmap: FT_Bitmap;
    bitmap_left: s32;
    bitmap_top: s32;
    
    outline: FT_Outline;
    
    num_subglyphs: FT_UInt;
    subglyphs: *void;
    
    control_data: *void;
    control_len: FT_Long;
    
    other: *void;
    
    lsb_delta: FT_Pos;
    rsb_delta: FT_Pos;
}

FT_GlyphSlotRec :: FT_GlyphSlot;

FT_FaceRec :: struct {
    num_faces: FT_Long;
    face_index: FT_Long;
    num_glyphs: FT_Long;
    family_name: *u8;
    style_name: *u8;
    height: FT_Short;
    glyph: *FT_GlyphSlot;
}

FT_Init_FreeType :: (alibrary: *FT_Library) -> FT_Error #foreign freetype;
FT_Done_FreeType :: (library: FT_Library) -> FT_Error #foreign freetype;
FT_New_Face :: (library: FT_Library, filepathname: *u8, face_index: FT_Long, aface: *FT_Face) -> FT_Error #foreign freetype;
FT_Done_Face :: (face: FT_Face) -> FT_Error #foreign freetype;
FT_Set_Pixel_Sizes :: (face: FT_Face, pixel_width: FT_UInt, pixel_height: FT_UInt) -> FT_Error #foreign freetype;
FT_Load_Glyph :: (face: FT_Face, glyph_index: FT_UInt, load_flags: FT_Int32) -> FT_Error #foreign freetype;
FT_Get_Char_Index :: (face: FT_Face, charcode: FT_ULong) -> FT_UInt #foreign freetype;

#scope_file

freetype :: #library "windows/freetype";
