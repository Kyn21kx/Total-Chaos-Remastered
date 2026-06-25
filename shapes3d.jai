#import "Basic";

G3D_DEG_TO_RAD :: PI / 180;

Mat4 :: struct {
    e: [16]float;
}

mat4_identity :: () -> Mat4 {
    result: Mat4;
    result.e[0] = 1;
    result.e[5] = 1;
    result.e[10] = 1;
    result.e[15] = 1;
    return result;
}

mat4_mul :: (a: Mat4, b: Mat4) -> Mat4 {
    result: Mat4;
    for col : 0..3 {
        for row : 0..3 {
            val: float = 0;
            for k : 0..3 {
                val += a.e[k * 4 + row] * b.e[col * 4 + k];
            }
            result.e[col * 4 + row] = val;
        }
    }
    return result;
}

mat4_perspective :: (fov_y: float, aspect: float, near: float, far: float) -> Mat4 {
    result: Mat4 = .{};
    tan_half_fov := tan(fov_y * 0.5);
    result.e[0] = 1.0 / (aspect * tan_half_fov);
    result.e[5] = 1.0 / tan_half_fov;
    result.e[10] = -(far + near) / (far - near);
    result.e[11] = -1.0;
    result.e[14] = -2.0 * far * near / (far - near);
    return result;
}

mat4_look_at :: (eye: Vector3, target: Vector3, up: Vector3) -> Mat4 {
    forward := normalize(target - eye);
    right := normalize(cross(forward, up));
    up_vector := cross(right, forward);

    result: Mat4 = .{};
    result.e[0] = right.x;
    result.e[4] = right.y;
    result.e[8] = right.z;
    result.e[12] = -dot(right, eye);

    result.e[1] = up_vector.x;
    result.e[5] = up_vector.y;
    result.e[9] = up_vector.z;
    result.e[13] = -dot(up_vector, eye);

    result.e[2] = -forward.x;
    result.e[6] = -forward.y;
    result.e[10] = -forward.z;
    result.e[14] = dot(forward, eye);

    result.e[15] = 1;
    return result;
}

mat4_translate :: (t: Vector3) -> Mat4 {
    result := mat4_identity();
    result.e[12] = t.x;
    result.e[13] = t.y;
    result.e[14] = t.z;
    return result;
}

mat4_scale :: (s: Vector3) -> Mat4 {
    result: Mat4 = .{};
    result.e[0] = s.x;
    result.e[5] = s.y;
    result.e[10] = s.z;
    result.e[15] = 1;
    return result;
}

mat4_rotate_x :: (angle: float) -> Mat4 {
    result := mat4_identity();
    c := cos(angle);
    s := sin(angle);
    result.e[5] = c;
    result.e[6] = s;
    result.e[9] = -s;
    result.e[10] = c;
    return result;
}

mat4_rotate_y :: (angle: float) -> Mat4 {
    result := mat4_identity();
    c := cos(angle);
    s := sin(angle);
    result.e[0] = c;
    result.e[2] = -s;
    result.e[8] = s;
    result.e[10] = c;
    return result;
}

mat4_rotate_z :: (angle: float) -> Mat4 {
    result := mat4_identity();
    c := cos(angle);
    s := sin(angle);
    result.e[0] = c;
    result.e[1] = s;
    result.e[4] = -s;
    result.e[5] = c;
    return result;
}

mat4_transform :: (v: Vector3, m: Mat4) -> Vector4 {
    return Vector4.{
        m.e[0] * v.x + m.e[4] * v.y + m.e[8]  * v.z + m.e[12],
        m.e[1] * v.x + m.e[5] * v.y + m.e[9]  * v.z + m.e[13],
        m.e[2] * v.x + m.e[6] * v.y + m.e[10] * v.z + m.e[14],
        m.e[3] * v.x + m.e[7] * v.y + m.e[11] * v.z + m.e[15]
    };
}

Camera3D :: struct {
    position: Vector3;
    target: Vector3;
    up: Vector3;
    fov: float;
    near_clip: float;
    far_clip: float;
}

DEFAULT_CAMERA_3D :: Camera3D.{
    position = .{0, 0, 6},
    target = .{0, 0, 0},
    up = .{0, 1, 0},
    fov = 50.0 * G3D_DEG_TO_RAD,
    near_clip = 0.1,
    far_clip = 100.0
};

project_vertex :: (v: Vector3, mvp: Mat4, screen_w: float, screen_h: float) -> Vector2 {
    clip := mat4_transform(v, mvp);
    if clip.w <= 0 return .{0, 0};
    ndc := Vector2.{clip.x / clip.w, clip.y / clip.w};
    return Vector2.{
        (ndc.x + 1.0) * 0.5 * screen_w,
        (ndc.y + 1.0) * 0.5 * screen_h
    };
}

is_vertex_visible :: (v: Vector3, mvp: Mat4) -> bool {
    clip := mat4_transform(v, mvp);
    if clip.w <= 0 return false;
    ndc_x := clip.x / clip.w;
    ndc_y := clip.y / clip.w;
    ndc_z := clip.z / clip.w;
    return ndc_x >= -1 && ndc_x <= 1 && ndc_y >= -1 && ndc_y <= 1 && ndc_z >= -1 && ndc_z <= 1;
}

build_model_matrix :: (position: Vector3, rotation: Vector3, scale: Vector3) -> Mat4 {
    t := mat4_translate(position);
    rx := mat4_rotate_x(rotation.x);
    ry := mat4_rotate_y(rotation.y);
    rz := mat4_rotate_z(rotation.z);
    s := mat4_scale(scale);
    return mat4_mul(mat4_mul(mat4_mul(mat4_mul(t, rx), ry), rz), s);
}

draw_triangle_3d :: (v0: Vector3, v1: Vector3, v2: Vector3, color: Vector4, mvp: Mat4, sw: float, sh: float) {
    a := project_vertex(v0, mvp, sw, sh);
    b := project_vertex(v1, mvp, sw, sh);
    c_ := project_vertex(v2, mvp, sw, sh);

    visible_a := is_vertex_visible(v0, mvp);
    visible_b := is_vertex_visible(v1, mvp);
    visible_c := is_vertex_visible(v2, mvp);

    if !visible_a && !visible_b && !visible_c return;

    Simp.immediate_triangle(
        .{a.x, a.y, 0},
        .{b.x, b.y, 0},
        .{c_.x, c_.y, 0},
        color, color, color
    );
}

draw_box_3d :: (position: Vector3, size: Vector3, rotation: Vector3, color: Vector4, camera: Camera3D, screen_w: float, screen_h: float) {
    Simp.set_shader_for_color(true);

    view := mat4_look_at(camera.position, camera.target, camera.up);
    proj := mat4_perspective(camera.fov, screen_w / screen_h, camera.near_clip, camera.far_clip);
    model := build_model_matrix(position, rotation, size);
    mvp := mat4_mul(mat4_mul(proj, view), model);

    hs := Vector3.{size.x * 0.5, size.y * 0.5, size.z * 0.5};
    corners := Vector3.[
        .{-hs.x, -hs.y, -hs.z},
        .{ hs.x, -hs.y, -hs.z},
        .{ hs.x,  hs.y, -hs.z},
        .{-hs.x,  hs.y, -hs.z},
        .{-hs.x, -hs.y,  hs.z},
        .{ hs.x, -hs.y,  hs.z},
        .{ hs.x,  hs.y,  hs.z},
        .{-hs.x,  hs.y,  hs.z},
    ];

    // Each face: two triangles, CCW winding
    // front (+Z): 4,5,6,7
    draw_triangle_3d(corners[4], corners[5], corners[6], color, mvp, screen_w, screen_h);
    draw_triangle_3d(corners[4], corners[6], corners[7], color, mvp, screen_w, screen_h);
    // back (-Z): 1,0,3,2
    draw_triangle_3d(corners[1], corners[0], corners[3], color, mvp, screen_w, screen_h);
    draw_triangle_3d(corners[1], corners[3], corners[2], color, mvp, screen_w, screen_h);
    // bottom (-Y): 4,0,1,5
    draw_triangle_3d(corners[4], corners[0], corners[1], color, mvp, screen_w, screen_h);
    draw_triangle_3d(corners[4], corners[1], corners[5], color, mvp, screen_w, screen_h);
    // top (+Y): 7,6,2,3
    draw_triangle_3d(corners[7], corners[6], corners[2], color, mvp, screen_w, screen_h);
    draw_triangle_3d(corners[7], corners[2], corners[3], color, mvp, screen_w, screen_h);
    // left (-X): 4,7,3,0
    draw_triangle_3d(corners[4], corners[7], corners[3], color, mvp, screen_w, screen_h);
    draw_triangle_3d(corners[4], corners[3], corners[0], color, mvp, screen_w, screen_h);
    // right (+X): 5,1,2,6
    draw_triangle_3d(corners[5], corners[1], corners[2], color, mvp, screen_w, screen_h);
    draw_triangle_3d(corners[5], corners[2], corners[6], color, mvp, screen_w, screen_h);
}

draw_sphere_3d :: (position: Vector3, radius: float, color: Vector4, camera: Camera3D, screen_w: float, screen_h: float, stacks: int = 10, slices: int = 14) {
    Simp.set_shader_for_color(true);

    view := mat4_look_at(camera.position, camera.target, camera.up);
    proj := mat4_perspective(camera.fov, screen_w / screen_h, camera.near_clip, camera.far_clip);
    model := build_model_matrix(position, .{0, 0, 0}, .{radius, radius, radius});
    mvp := mat4_mul(mat4_mul(proj, view), model);

    for i : 0..stacks - 1 {
        theta0 := PI * cast(float) i / cast(float) stacks;
        theta1 := PI * cast(float) (i + 1) / cast(float) stacks;
        sin_theta0 := sin(theta0);
        cos_theta0 := cos(theta0);
        sin_theta1 := sin(theta1);
        cos_theta1 := cos(theta1);

        for j : 0..slices - 1 {
            phi0 := 2.0 * PI * cast(float) j / cast(float) slices;
            phi1 := 2.0 * PI * cast(float) (j + 1) / cast(float) slices;
            sin_phi0 := sin(phi0);
            cos_phi0 := cos(phi0);
            sin_phi1 := sin(phi1);
            cos_phi1 := cos(phi1);

            v0 := Vector3.{sin_theta0 * cos_phi0, cos_theta0, sin_theta0 * sin_phi0};
            v1 := Vector3.{sin_theta1 * cos_phi0, cos_theta1, sin_theta1 * sin_phi0};
            v2 := Vector3.{sin_theta1 * cos_phi1, cos_theta1, sin_theta1 * sin_phi1};
            v3 := Vector3.{sin_theta0 * cos_phi1, cos_theta0, sin_theta0 * sin_phi1};

            draw_triangle_3d(v0, v1, v3, color, mvp, screen_w, screen_h);
            draw_triangle_3d(v1, v2, v3, color, mvp, screen_w, screen_h);
        }
    }
}

draw_prism_3d :: (position: Vector3, radius: float, depth: float, rotation: Vector3, color: Vector4, camera: Camera3D, screen_w: float, screen_h: float) {
    Simp.set_shader_for_color(true);

    view := mat4_look_at(camera.position, camera.target, camera.up);
    proj := mat4_perspective(camera.fov, screen_w / screen_h, camera.near_clip, camera.far_clip);
    model := build_model_matrix(position, rotation, .{1, 1, 1});
    mvp := mat4_mul(mat4_mul(proj, view), model);

    half_depth := depth * 0.5;

    // 3 vertices of the equilateral triangle (CCW, circumradius = radius)
    angle0 := PI / 2.0;
    angle1 := 7.0 * PI / 6.0;
    angle2 := 11.0 * PI / 6.0;

    front_verts := Vector3.[
        .{radius * cos(angle0), radius * sin(angle0),  half_depth},
        .{radius * cos(angle1), radius * sin(angle1),  half_depth},
        .{radius * cos(angle2), radius * sin(angle2),  half_depth},
    ];
    back_verts := Vector3.[
        .{front_verts[0].x, front_verts[0].y, -half_depth},
        .{front_verts[1].x, front_verts[1].y, -half_depth},
        .{front_verts[2].x, front_verts[2].y, -half_depth},
    ];

    // Front face (CCW)
    draw_triangle_3d(front_verts[0], front_verts[1], front_verts[2], color, mvp, screen_w, screen_h);
    // Back face (CCW, reversed winding from front)
    draw_triangle_3d(back_verts[2], back_verts[1], back_verts[0], color, mvp, screen_w, screen_h);

    // 3 rectangular sides
    for i : 0..2 {
        j := (i + 1) % 3;
        draw_triangle_3d(front_verts[i], front_verts[j], back_verts[i], color, mvp, screen_w, screen_h);
        draw_triangle_3d(front_verts[j], back_verts[j], back_verts[i], color, mvp, screen_w, screen_h);
    }
}
