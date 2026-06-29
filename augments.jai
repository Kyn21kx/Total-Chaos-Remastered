EAugment :: enum u16 {
    None :: 0;
    ChaosChain :: 1;
    GetEmClose :: 2;
    Savior :: 4;
}

AUGMENT_NAMES :: string.["Chaos Chain", "Get 'em Close!", "Savior"] ;

AUGMENT_COUNT :: 3;

g_augmentBits: EAugment = .None;
g_augmentPickActive: bool;
g_augmentPickOptions: [3] int;
g_augmentPickHoverIndex: int = -1;
g_augmentPickHoverScale: [3] float;
g_augmentPickSelected: int = -1;
g_augmentPickConfirmTimer: float;
g_augmentPickRotation: float;

CARD_HOVER_SCALE :: 1.15;
CARD_HOVER_RADIUS :: 140.0;
CARD_ICON_SIZE_RADIUS :: 0.9;
CARD_WORLD_Y :: 0.0;

GetCardWorldPos :: (index: int) -> Vector3 {
    offset := cast(float)(index - 1) * 2.8;
    return Vector3.{offset, CARD_WORLD_Y, 0};
}

GetCardColor :: (index: int) -> Vector4 {
    if index == 0 return Vector4.{0.2, 0.5, 1.0, 1.0};
    if index == 1 return Vector4.{0.2, 1.0, 0.5, 1.0};
    return Vector4.{1.0, 0.4, 0.6, 1.0};
}

ShouldStartAugmentPick :: () -> bool {
    return g_waveNumber % 3 == 0 && g_isWaveCleared && !g_augmentPickActive && g_waveAnnouncementTimer <= 0;
}

InitAugmentPick :: () {
    chosen: [AUGMENT_COUNT] bool;
    for i : 0..2 {
        while true {
            candidate := RandIntInRange(0, AUGMENT_COUNT);
            if !chosen[candidate] {
                chosen[candidate] = true;
                g_augmentPickOptions[i] = candidate;
                break;
            }
        }
    }
    g_augmentPickHoverIndex = -1;
    g_augmentPickHoverScale[0] = 1.0;
    g_augmentPickHoverScale[1] = 1.0;
    g_augmentPickHoverScale[2] = 1.0;
    g_augmentPickSelected = -1;
    g_augmentPickConfirmTimer = 0;
    g_augmentPickRotation = 0;
    g_augmentPickActive = true;
}

DrawAugmentCardGlow :: (screenPos: Vector2, color: Vector4, scale: float) {
    glowColor := Vector4.{color.x, color.y, color.z, 0.15};
    DrawCircle(screenPos, 50.0 * scale, glowColor, 24);
    DrawCircle(screenPos, 35.0 * scale, Vector4.{color.x, color.y, color.z, 0.08}, 24);
}

DrawAugmentCardName :: (screenPos: Vector2, nameText: string, index: int, scale: float) {
    text_width := Simp.prepare_text(g_font, nameText);
    textPos := Vector2.{screenPos.x - text_width * 0.5, screenPos.y - 65.0 * scale};
    Simp.draw_prepared_text(g_font, xx textPos.x, xx textPos.y, .{0, 0, 0, 1.0});
}

DrawAugmentPick :: () {
    if !g_augmentPickActive return;

    view := mat4_look_at(DEFAULT_CAMERA_3D.position, DEFAULT_CAMERA_3D.target, DEFAULT_CAMERA_3D.up);
    proj := mat4_perspective(DEFAULT_CAMERA_3D.fov, cast(float)width / cast(float)height, DEFAULT_CAMERA_3D.near_clip, DEFAULT_CAMERA_3D.far_clip);

    vp := mat4_mul(proj, view);

    for i : 0..2 {
        worldPos := GetCardWorldPos(i);
        screenPos := project_vertex(worldPos, vp, cast(float)width, cast(float)height);

        color := GetCardColor(i);

        DrawAugmentCardGlow(screenPos, color, g_augmentPickHoverScale[i]);

        idx := g_augmentPickOptions[i];
        shapeType := idx % 3;
        if shapeType == 0 {
            draw_box_3d(worldPos, .{CARD_ICON_SIZE_RADIUS * g_augmentPickHoverScale[i], CARD_ICON_SIZE_RADIUS * g_augmentPickHoverScale[i], CARD_ICON_SIZE_RADIUS * g_augmentPickHoverScale[i]}, .{0, g_augmentPickRotation, g_augmentPickRotation * 0.3}, color, DEFAULT_CAMERA_3D, cast(float)width, cast(float)height);
        }
        else if shapeType == 1 {
            draw_sphere_3d(worldPos, CARD_ICON_SIZE_RADIUS * g_augmentPickHoverScale[i], color, DEFAULT_CAMERA_3D, cast(float)width, cast(float)height);
        }
        else {
            draw_prism_3d(worldPos, CARD_ICON_SIZE_RADIUS * g_augmentPickHoverScale[i], CARD_ICON_SIZE_RADIUS * g_augmentPickHoverScale[i] * 1.5, .{0, g_augmentPickRotation, g_augmentPickRotation * 0.3}, color, DEFAULT_CAMERA_3D, cast(float)width, cast(float)height);
        }

        nameText := AUGMENT_NAMES[idx];
        DrawAugmentCardName(screenPos, nameText, i, g_augmentPickHoverScale[i]);
    }

    if g_augmentPickSelected >= 0 {
        confirmText := "Selected!";
        text_width := Simp.prepare_text(g_font, confirmText);
        Simp.draw_prepared_text(g_font, xx ((cast(float)width - text_width) * 0.5), xx (cast(float)height * 0.15), Vector4.{1, 1, 0, 1});
    }
    else {
        promptText := "Choose an augment";
        text_width := Simp.prepare_text(g_font, promptText);
        Simp.draw_prepared_text(g_font, xx ((cast(float)width - text_width) * 0.5), xx (cast(float)height * 0.15), Vector4.{0.8, 0.8, 0.8, 1});
    }
}

UpdateAugmentPick :: (delta: float) {
    if !g_augmentPickActive return;

    g_augmentPickRotation += delta * 0.6;

    if g_augmentPickSelected >= 0 {
        g_augmentPickConfirmTimer -= delta;
        if g_augmentPickConfirmTimer <= 0 {
            g_augmentPickActive = false;
            StartNewWave();
        }
        return;
    }

    view := mat4_look_at(DEFAULT_CAMERA_3D.position, DEFAULT_CAMERA_3D.target, DEFAULT_CAMERA_3D.up);
    proj := mat4_perspective(DEFAULT_CAMERA_3D.fov, cast(float)width / cast(float)height, DEFAULT_CAMERA_3D.near_clip, DEFAULT_CAMERA_3D.far_clip);

    vp := mat4_mul(proj, view);

    g_augmentPickHoverIndex = -1;
    closestDist := CARD_HOVER_RADIUS;

    for i : 0..2 {
        worldPos := GetCardWorldPos(i);
        screenPos := project_vertex(worldPos, vp, cast(float)width, cast(float)height);
        dist := magnitude(g_mousePosition - screenPos);
        if dist < closestDist {
            closestDist = dist;
            g_augmentPickHoverIndex = i;
        }
    }

    for i : 0..2 {
        targetScale : float = 1.0;
        if i == g_augmentPickHoverIndex targetScale = CARD_HOVER_SCALE;
        g_augmentPickHoverScale[i] += (targetScale - g_augmentPickHoverScale[i]) * delta * 8.0;
    }

    if g_augmentPickHoverIndex >= 0 && (g_inputStateThisFrame & .MousePressedLeft) {
        g_augmentPickSelected = g_augmentPickHoverIndex;
        g_augmentPickConfirmTimer = 0.5;
        augmentBit := cast(EAugment)(1 << g_augmentPickOptions[g_augmentPickSelected]);
        g_augmentBits |= augmentBit;
    }
}
