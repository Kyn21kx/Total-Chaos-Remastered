#import "Basic";
#import "Window_Creation";
#import "Input";
#import "Math";
#import "System";
Simp :: #import "Simp";


EEntityType :: enum u16 {
	None;
	Player;
	Enemy;
}

EShape :: enum u16 {
	None;
	Circle;
	Triangle;
}

Entity :: struct {
	position : Vector2;
	velocity : Vector2;
	rotation: float;

	speed: float;
	shape : EShape;
	shapeSize : float;
	color: Vector4;

	type : EEntityType;
}

DEFAULT_PLAYER_COLOR :: Vector4.{1, 0.2, 1, 1};
DEFAULT_PLAYER_SIZE_PX :: 25;

g_shouldQuitGame := false;
g_entities : [1024] Entity;
g_entityIndex := 0;

current_dt: float = 0.016667;
last_time:  float64;
DT_MAX : float : 0.15;

DrawEntity :: (entity: *Entity) {
	if (entity.shape == .Circle) {
		DrawCircle(entity.position, entity.shapeSize, entity.color);
	}
	else if (entity.shape == .Triangle) {
		DrawTriangle(entity.position, entity.shapeSize, entity.rotation, entity.color);
	}
}

ApplyMovement :: (entity: *Entity, deltaTime: float) {
	entity.position += entity.velocity * deltaTime * entity.speed;
}

UpdatePlayer :: (entity: *Entity) {
	entity.velocity = Vector2.{0, 0};
	for event : events_this_frame {
		if event.type == .QUIT {
			g_shouldQuitGame = true;
		}

		if event.type != .KEYBOARD || !event.key_pressed {
        	break;
	    }
        if event.key_code == .ESCAPE {
	        g_shouldQuitGame = true;
        }
	}
	
	if input_button_states[cast(int) #char "W"] & .DOWN {
    	entity.velocity += Vector2.{0, 1};
	}
	if input_button_states[cast(int) #char "A"] & .DOWN {
    	entity.velocity += Vector2.{-1, 0};
	}
	if input_button_states[cast(int) #char "S"] & .DOWN {
    	entity.velocity += Vector2.{0, -1};
	}
	if input_button_states[cast(int) #char "D"] & .DOWN {
    	entity.velocity += Vector2.{1, 0};
	}

	entity.velocity = normalize(entity.velocity);
	
}

Update :: () {
    now := seconds_since_init();
    delta : float64 = now - last_time;
    current_dt = cast(float) delta;

    if current_dt > DT_MAX current_dt = DT_MAX;

    last_time = now;
    
	for entity : g_entities {
		if (entity.type == .None) continue;
		DrawEntity(*entity);
		if (entity.type == .Player) {
			UpdatePlayer(*entity);
		}
		ApplyMovement(*entity, current_dt);
	}
}

DEFAULT_ENEMY_SPEED :: 700;
DEFAULT_ENEMY_SIZE_PX :: 25;

CreateEnemy :: (position: Vector2) -> Entity {
	result := Entity.{
		position = position,
		speed = DEFAULT_ENEMY_SPEED,
		shape = .Triangle,
		shapeSize = DEFAULT_ENEMY_SIZE_PX,
		color = Vector4.{1, 1, 1, 1},
		type = .Enemy
	};
	return result;
}

AddEntity :: (entity: Entity) {
	g_entities[g_entityIndex] = entity;
	g_entityIndex += 1;
}

main :: () {
	width := 1080;
	height := 720;
	
	last_time = seconds_since_init();	
	window := create_window(window_name="TotalChaos Remastered", width=width, height=height);	
    Simp.set_render_target(window);

    // Create the player
    player := Entity.{
		type = .Player,
		shape = .Triangle,
		shapeSize = DEFAULT_PLAYER_SIZE_PX,
		color = DEFAULT_PLAYER_COLOR,
		speed = 500,
		position = .{width / 2.0, height / 2.0},
	};

	AddEntity(player);
	
	enemy := CreateEnemy(Vector2.{width / 2.0, height / 1.5});
	AddEntity(enemy);

    while !g_shouldQuitGame {
		reset_temporary_storage();
		update_window_events();	
        Simp.clear_render_target(.2, .3, .3, 1);
        Update();
        Simp.swap_buffers(window);
	}
    
}


DrawCircle :: (center: Vector2, radius: float, color: Vector4, segments: int = 32) {
    Simp.set_shader_for_color();

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


DrawTriangle :: (center: Vector2, size: float, angle: float, color: Vector4) {
    // Define the three points of the triangle relative to center
    // Pointing up by default
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

    Simp.set_shader_for_color();
    Simp.immediate_triangle(
        .{rotated[0].x, rotated[0].y, 0},
        .{rotated[1].x, rotated[1].y, 0},
        .{rotated[2].x, rotated[2].y, 0},
        color, color, color
    );
}
