#import "Basic";
#import "Window_Creation";
#import "Input";
#import "Math";
#import "System";
Simp :: #import "Simp";
#load "entity.jai";
#load "random_utils.jai";

SpawnPoint :: enum u8 {
	Top;
	Bottom;
	Left;
	Right;
}

DEFAULT_PLAYER_COLOR :: Vector4.{1, 0.2, 1, 1};
DEFAULT_PLAYER_SIZE_PX :: 25;

DEFAULT_BULLET_SPEED : float : 800; 
DEFAULT_BULLET_DAMAGE : float : 10; 
DEFAULT_HEALTH : float : 10; 
DEFAULT_BULLET_SIZE_PX :: 15; 

PLAYER_BULLET_COLOR :: Vector4.{1, 0.1, 1, 1};

ENEMY_SPAWN_TIME_THRESHOLD_IN_SECONDS : float64 : 2;

VEC2_DOWN :: Vector2.{0, -1};
VEC2_UP :: Vector2.{0, 1};
VEC2_LEFT :: Vector2.{-1, 0};
VEC2_RIGHT :: Vector2.{1, 0};

g_shouldQuitGame := false;
g_entities : [2048] Entity;
g_entityIndex := 0;
g_mousePosition: Vector2;
g_currentTime : float64 = 0;

g_enemySpawnTimer : float64 = 0;

g_debugMousePtrEntityId := -1;

width := 1080;
height := 720;

current_dt: float = 0.016667;
last_time:  float64;
DT_MAX : float : 0.15;

ScreenLowerLeft :: () -> Vector2 {
    return .{0.0, 0.0};
}
ScreenUpperLeft :: () -> Vector2 {
    return .{0.0, cast(float) height};
}
ScreenUpperRight :: () -> Vector2 {
    return .{cast(float) width, cast(float) height};
}
ScreenLowerRight :: () -> Vector2 {
    return .{cast(float) width, 0.0};
}

DrawEntity :: (entity: *Entity) {
	if (entity.shape == .Circle) {
		DrawCircle(entity.position, entity.shapeSize, entity.color);
	}
	else if (entity.shape == .Triangle) {
		DrawTriangle(entity.position, entity.shapeSize, entity.rotation, entity.color);
	}
}

CalculateRandomSpawnPoint :: (outSpawnPoint: *SpawnPoint) -> Vector2 {
	spotNumericMin := cast(u8)SpawnPoint.Top;
	spotNumericMax := (cast(u8)SpawnPoint.Right) + 1;
	<< outSpawnPoint = cast(SpawnPoint)RandIntInRange(spotNumericMin, spotNumericMax);

	if #complete << outSpawnPoint == {
		case .Top; return RandVec2(ScreenUpperLeft(), ScreenUpperRight());
		case .Bottom; return RandVec2(ScreenLowerLeft(), ScreenLowerRight());
		case .Left; return RandVec2(ScreenLowerLeft(), ScreenUpperLeft());
		case .Right; return RandVec2(ScreenLowerRight(), ScreenUpperRight());
	}
}

SpawnPointDefaultTravelDir :: (spawnPosition: SpawnPoint, entity: *Entity) -> Vector2 {
	if #complete spawnPosition == {
		case .Top; return VEC2_DOWN;
		case .Bottom; return VEC2_UP;
		case .Left; return VEC2_RIGHT;
		case .Right; return VEC2_LEFT;
	}
}

// This will spawn if some time and probability is met
SpawnEntities :: (delta: float64) {
	g_enemySpawnTimer += delta;
	if (g_enemySpawnTimer >= ENEMY_SPAWN_TIME_THRESHOLD_IN_SECONDS) {
		spawnPointGuide : SpawnPoint;
		randomPosition := CalculateRandomSpawnPoint(*spawnPointGuide);
		enemy := CreateEnemy(randomPosition);
		enemy.velocity = SpawnPointDefaultTravelDir(spawnPointGuide, *enemy);
		AddEntity(enemy);
		g_enemySpawnTimer = 0.0;
	}
}

ApplyMovement :: (entity: *Entity, deltaTime: float) {
	entity.position += entity.velocity * deltaTime * entity.speed;
	entity.rotation += entity.rotationVelocity * deltaTime;
	if (entity.rotation > 360.0) {
		entity.rotation = 0;
	}
	else if (entity.rotation < 0.0) {
		entity.rotation = 360.0;
	}
	if (entity.position.x > cast(float)width) {
		entity.position.x = 0;
	}
	else if (entity.position.x < 0) {
		entity.position.x = cast(float)width;
	}

	if (entity.position.y > cast(float)height) {
		entity.position.y = 0;
	}
	if (entity.position.y < 0) {
		entity.position.y = cast(float)height;
	}
}

AngleBetween :: (a: Vector2, b: Vector2) -> float {
    return atan2(b.y - a.y, b.x - a.x);
}

ShootBullet :: (position: Vector2, shootDir: Vector2, color: Vector4) {
	bullet := Entity.{
		type = .Bullet,
		position = position,
		speed = DEFAULT_BULLET_SPEED,
		shape = .Circle,
		shapeSize = DEFAULT_BULLET_SIZE_PX,
		color = color,
		damage = DEFAULT_BULLET_DAMAGE,
		velocity = shootDir,
		initialLifetime = 3,
		remainingLifetime = 3,
	};
	
	AddEntity(bullet);
}

EnemyShoot :: (entity: *Entity) {
	
}

PlayerShoot :: (entity: *Entity) {
	shootDir := normalize(g_mousePosition - entity.position);
	ShootBullet(entity.position, shootDir, PLAYER_BULLET_COLOR);
}

HandleCollision :: (first: *Entity, second: *Entity) {
	print("Collision between % and %\n", first.id, second.id);
	if (first.type == .Bullet && second.type == .Enemy) {
		second.health -= first.damage;
		// Again, we should probably address entity deletion some day
		first.type = .None;
		second.cacheVelocity = second.velocity;
		second.velocity = first.velocity * 2;
		second.state = .Knockback;
		return;
	}
	if (first.type == .Player && second.type == .Enemy) {
		
		return;
	}
}

CollisionSystem :: (entity: *Entity) {
	// Collision layer is not applied to this entity
	if ((entity.type & EEntityType.CollisionEnabledLayer) == 0) {
		return;
	}
	// Filter out the collision masks if this gets too slow
	for other : g_entities {
		// Cannot collide with ourselves
		otherHasCollisionLayer : bool = (other.type & EEntityType.CollisionEnabledLayer) != 0;
		if (other.id == entity.id || !otherHasCollisionLayer) continue;
		collidesOnX := entity.position.x >= other.position.x - other.shapeSize && entity.position.x <= other.position.x + other.shapeSize;
		collidesOnY := entity.position.y >= other.position.y - other.shapeSize && entity.position.y <= other.position.y + other.shapeSize;
		if (collidesOnX && collidesOnY) {
			HandleCollision(entity, *other);
		}
	}
}

DebugEntities :: () {
	if (g_debugMousePtrEntityId == -1) {
		mousePtrGuide := Entity.{
			type = .Debug,
			position = g_mousePosition,
			shape = .Circle,
			shapeSize = 20,
			color = Vector4.{0, 0, 0, 1}
		};
		g_debugMousePtrEntityId = AddEntity(mousePtrGuide);
	}
	g_entities[g_debugMousePtrEntityId].position = g_mousePosition;
}

approximately_equal :: (a: Vector2, b: Vector2, epsilon: float = 0.0001) -> bool {
    return abs(a.x - b.x) < epsilon && abs(a.y - b.y) < epsilon;
}

HandleKnockback :: (entity: *Entity, delta: float) {
	// Lerp the velocity to 0
	KNOCKBACK_RECOVER_SPEED : float : 5.0;
	entity.velocity = lerp(entity.velocity, Vector2.{0, 0}, delta * KNOCKBACK_RECOVER_SPEED);
	if approximately_equal(entity.velocity, Vector2.{0, 0}) {
		// Restore its cached velocity
		entity.velocity = entity.cacheVelocity;
		entity.state = .None;
	}
}

HandleSpecialStates :: (entity: *Entity, delta: float) {
	if #complete entity.state == {
		case .None; return;
		case .Knockback; HandleKnockback(entity, delta);
	}
	
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
		if (event.key_code == .MOUSE_BUTTON_LEFT) {
			PlayerShoot(entity);
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
	// entity.rotation = -(AngleBetween(entity.position, g_mousePosition)) - PI / 2.0;
}

HealthSystem :: (entity: *Entity) {
	if (entity.type != .Enemy && entity.type != .Player) {
		return;
	}
	if (entity.health <= 0) {
		entity.type = .None;
		return;
	}
	// Damage animation
}

FadeEntityOverTime :: (entity: *Entity, delta: float64) {
	if (entity.type != .Bullet) {
		return;
	}
	if (entity.remainingLifetime <= 0) {
		// TODO: handle proper removal with entity recycling
		entity.type = .None;
	}

	entity.remainingLifetime -= cast(float)delta;
	// Fade the color's opacity
	lerpingBlend := entity.remainingLifetime / entity.initialLifetime;
	entity.color.w = lerp(0.4, 1.0, lerpingBlend);
	// entity.shapeSize = lerp(5, DEFAULT_BULLET_SIZE_PX, lerpingBlend);
}


Update :: () {
    now := seconds_since_init();
    delta : float64 = now - last_time;
    current_dt = cast(float) delta;

    if current_dt > DT_MAX current_dt = DT_MAX;

    last_time = now;

	g_currentTime += delta;
	
	// DebugEntities();

	SpawnEntities(delta);
	for entity : g_entities {
		if (entity.type == .None) continue;
		DrawEntity(*entity);
		FadeEntityOverTime(*entity, delta);
		CollisionSystem(*entity);
		
		if (entity.type == .Player) {
			UpdatePlayer(*entity);
		}
		
		HandleSpecialStates(*entity, current_dt);
		ApplyMovement(*entity, current_dt);
		HealthSystem(*entity);
	}
}

DEFAULT_ENEMY_SPEED :: 300;
DEFAULT_ENEMY_SIZE_PX :: 25;

CreateEnemy :: (position: Vector2) -> Entity {
	result := Entity.{
		position = position,
		speed = DEFAULT_ENEMY_SPEED,
		shape = .Triangle,
		shapeSize = DEFAULT_ENEMY_SIZE_PX,
		color = Vector4.{1, 1, 1, 1},
		health = DEFAULT_HEALTH * 2,
		type = .Enemy
	};
	return result;
}

AddEntity :: (entity: Entity) -> s64 {
	retVal := g_entityIndex;
	g_entities[g_entityIndex] = entity;
	g_entities[g_entityIndex].id = retVal;
	g_entityIndex += 1;
	return retVal;
}

main :: () {
	last_time = seconds_since_init();	
	window := create_window(window_name="TotalChaos Remastered", width=width, height=height);	
    Simp.set_render_target(window);

    // Create the player
    player := Entity.{
		type = .Player,
		shape = .Triangle,
		shapeSize = DEFAULT_PLAYER_SIZE_PX,
		color = DEFAULT_PLAYER_COLOR,
		health = DEFAULT_HEALTH * 10, // N hits
		speed = 500,
		position = .{width / 2.0, height / 2.0},
	};

	AddEntity(player);
	
	enemy := CreateEnemy(Vector2.{width / 2.0, height / 1.5});
	AddEntity(enemy);

    while !g_shouldQuitGame {
		reset_temporary_storage();
		update_window_events();	
		mouseX, mouseY := get_mouse_pointer_position();	
        Clamp(*mouseY, 0, height);
        Clamp(*mouseX, 0, width);
		g_mousePosition = Vector2.{cast(float) mouseX, height - cast(float)mouseY};
        Simp.clear_render_target(.2, .3, .3, 1);
        Update();
        Simp.swap_buffers(window);
	}
    
}


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
