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


DrawGradientCircle :: (center: Vector2, radius: float, color: Vector4, segments: int = 32) {
    Simp.set_shader_for_color(true);
    step := (2.0 * PI) / cast(float) segments;

    innerRadius := radius * 0.7;
    outerColor  := color;
    innerColor  := Vector4.{color.x, color.y, color.z, 0.0};

    for i : 0..segments-1 {
        angle0 := step * cast(float) i;
        angle1 := step * cast(float) (i + 1);

        // Outer ring points
        ox0 := center.x + cos(angle0) * radius;
        oy0 := center.y + sin(angle0) * radius;
        ox1 := center.x + cos(angle1) * radius;
        oy1 := center.y + sin(angle1) * radius;

        // Inner ring points
        ix0 := center.x + cos(angle0) * innerRadius;
        iy0 := center.y + sin(angle0) * innerRadius;
        ix1 := center.x + cos(angle1) * innerRadius;
        iy1 := center.y + sin(angle1) * innerRadius;

        // Outer quad (two triangles) — outer solid, inner transparent
        Simp.immediate_triangle(
            .{ox0, oy0, 0},
            .{ox1, oy1, 0},
            .{ix0, iy0, 0},
            outerColor,
            outerColor,
            innerColor
        );
        Simp.immediate_triangle(
            .{ox1, oy1, 0},
            .{ix1, iy1, 0},
            .{ix0, iy0, 0},
            outerColor,
            innerColor,
            innerColor
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

