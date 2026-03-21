#import "Basic";
#import "Window_Creation";
#import "Input";
#import "Math";
#import "System";
#load "draw_utils.jai";
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

DEFAULT_BULLET_SPEED : float : 1000; 
DEFAULT_BULLET_DAMAGE : float : 10; 
DEFAULT_HEALTH : float : 10; 
DEFAULT_BULLET_SIZE_PX :: 20;


DEFAULT_ENEMY_HEALTH :: DEFAULT_HEALTH * 2;
PLAYER_BULLET_COLOR :: Vector4.{0, 0.2, 1, 1};

ENEMY_SPAWN_TIME_THRESHOLD_IN_SECONDS : float64 : 2;

VEC2_DOWN :: Vector2.{0, -1};
VEC2_UP :: Vector2.{0, 1};
VEC2_LEFT :: Vector2.{-1, 0};
VEC2_RIGHT :: Vector2.{1, 0};

// We want the bullets to bounce off of each other, so we include the bullet collision mask
ENEMY_BULLET_COLLISION_MASK : EEntityType : .Player | .Bullet;

ENEMY_SHOOT_COOLDOWN_S :: 3.0;

// TBD
PLAYER_SHOOT_COOLDOWN_S :: 1.0;

g_shouldQuitGame := false;
g_entities : [2048] Entity;
g_entityIndex := 0;
g_mousePosition: Vector2;
g_currentTime : float64 = 0;

g_enemySpawnTimer : float64 = 0;

g_debugMousePtrEntityId := -1;
g_playerId := -1;

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

HandleCooldownTimers :: (entity: *Entity, delta: float) {
	if (entity.shootCooldownTimer > 0) {
		entity.shootCooldownTimer -= delta;
	}
}

DrawHealthBar :: (entity: *Entity, delta: float) {
	
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

ShootBullet :: (position: Vector2, shootDir: Vector2, color: Vector4, collisionMask: EEntityType, speed: float = DEFAULT_BULLET_SPEED) {
	bullet := Entity.{
		type = .Bullet,
		position = position,
		speed = speed,
		shape = .Circle,
		shapeSize = DEFAULT_BULLET_SIZE_PX,
		color = color,
		damage = DEFAULT_BULLET_DAMAGE,
		velocity = shootDir,
		initialLifetime = 3,
		remainingLifetime = 3,
		collisionMask = collisionMask
	};
	
	AddEntity(bullet);
}

EnemyShoot :: (entity: *Entity) {
	// Get the direction of the player
	if (entity.type != .Enemy || entity.shootCooldownTimer > 0) return;
	
	shootDir := normalize(g_entities[g_playerId].position - entity.position);
	ShootBullet(entity.position, shootDir, Vector4.{1, 0.01, 0, 1}, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
	entity.shootCooldownTimer = ENEMY_SHOOT_COOLDOWN_S;
}

PlayerShoot :: (entity: *Entity) {
	shootDir := normalize(g_mousePosition - entity.position);
	ShootBullet(entity.position, shootDir, PLAYER_BULLET_COLOR, .Enemy | .Bullet, DEFAULT_BULLET_SPEED);
}

HandleCollision :: (first: *Entity, second: *Entity) {
	if (first.type == .Bullet && second.type == .Enemy) {
		second.health -= first.damage;
		// Again, we should probably address entity deletion some day
		first.type = .None;
		second.cacheVelocity = second.velocity;
		second.velocity = first.velocity * 4;
		second.state = .Knockback;
		OnDamaged(second);
		return;
	}
	if (first.type == .Player && second.type == .Bullet) {
		first.health -= second.damage;
		second.type = .None;
		// OnDamaged(first);
		return;
	}

	if (first.type == .Bullet && second.type == .Bullet) {
		firstVel := first.velocity;
		first.velocity = second.velocity;
		second.velocity = firstVel;
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
		isOtherWithinCollisionMask : bool = (other.type & entity.collisionMask) != 0 && (other.collisionMask & entity.type) != 0;
		if (other.id == entity.id || !otherHasCollisionLayer || !isOtherWithinCollisionMask) continue;

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

OnDamaged :: (entity: *Entity) {
	entity.cacheColor = entity.color;
	entity.color = Vector4.{1, 0, 0, 1};
}

OnRecoverFromDamage :: (entity: *Entity) {
	entity.color = lerp(entity.cacheColor, Vector4.{0, 0, 0, 0}, entity.health / DEFAULT_ENEMY_HEALTH);
}

HandleKnockback :: (entity: *Entity, delta: float) {
	// Lerp the velocity to 0
	KNOCKBACK_RECOVER_SPEED : float : 20.0;
	entity.velocity = lerp(entity.velocity, Vector2.{0, 0}, delta * KNOCKBACK_RECOVER_SPEED);
	if approximately_equal(entity.velocity, Vector2.{0, 0}) {
		// Restore its cached velocity
		entity.velocity = entity.cacheVelocity;
		entity.state = .None;
		OnRecoverFromDamage(entity);
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
		
		HandleCooldownTimers(*entity, current_dt);
		HandleSpecialStates(*entity, current_dt);
		EnemyShoot(*entity);
		ApplyMovement(*entity, current_dt);
		HealthSystem(*entity);
	}
}

DEFAULT_ENEMY_SPEED :: 200;
DEFAULT_ENEMY_SIZE_PX :: 25;

CreateEnemy :: (position: Vector2) -> Entity {
	result := Entity.{
		position = position,
		speed = DEFAULT_ENEMY_SPEED,
		shape = .Triangle,
		shapeSize = DEFAULT_ENEMY_SIZE_PX,
		color = Vector4.{1, 1, 1, 1},
		health = DEFAULT_ENEMY_HEALTH,
		shootCooldownTimer = ENEMY_SHOOT_COOLDOWN_S,
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

	g_playerId = AddEntity(player);
	
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

