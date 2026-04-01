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
    Simp.set_shader_for_color(true);
    Simp.immediate_quad(position.x, position.y, position.x + size.x, position.y + size.y, color);
}


DrawRect :: (position: Vector2, size: Vector2, color: Vector4, angle: float) {
    half_w := size.x / 2.0;
    half_h := size.y / 2.0;

    // Define corners relative to center
    corners := Vector2.[
        .{-half_w, -half_h},  // bottom left
        .{ half_w, -half_h},  // bottom right
        .{ half_w,  half_h},  // top right
        .{-half_w,  half_h},  // top left
    ];

    // Rotate and translate each corner
    ca := cos(angle);
    sa := sin(angle);

    rotated : [4] Vector2;
    for i : 0..3 {
        p := corners[i];
        rotated[i] = .{
            position.x + p.x * ca - p.y * sa,
            position.y + p.x * sa + p.y * ca,
        };
    }

    // Draw as two triangles
    Simp.set_shader_for_color(true);
    Simp.immediate_triangle(
        .{rotated[0].x, rotated[0].y, 0},
        .{rotated[1].x, rotated[1].y, 0},
        .{rotated[2].x, rotated[2].y, 0},
        color, color, color
    );
    Simp.immediate_triangle(
        .{rotated[0].x, rotated[0].y, 0},
        .{rotated[2].x, rotated[2].y, 0},
        .{rotated[3].x, rotated[3].y, 0},
        color, color, color
    );
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

