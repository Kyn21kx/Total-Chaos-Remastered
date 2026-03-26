#import "Basic";
#import "Window_Creation";
#import "Input";
#import "Math";
#import "System";
#import "Sound_Player";
#import "File";
#import "String";
#load "draw_utils.jai";
#load "entity.jai";
#load "random_utils.jai";

SpawnPoint :: enum u8 {
	Top;
	Bottom;
	Left;
	Right;
}

DEFAULT_PLAYER_COLOR :: Vector4.{3 / 255.0, 211 / 255.0, 252 / 255.0, 1};
DEFAULT_PLAYER_SIZE_PX :: 25;

DEFAULT_BULLET_SPEED : float : 1000; 
DEFAULT_BULLET_DAMAGE : float : 10; 
DEFAULT_HEALTH : float : 10; 
DEFAULT_BULLET_SIZE_PX :: 20;

STAMINA_PER_BULLET :: 30;
DEFAULT_PLAYER_STAMINA :: 100;

SUCCESSFUL_PARRY_WINDOW_S :: 0.3;

DEFAULT_ENEMY_HEALTH :: DEFAULT_HEALTH * 2;
PLAYER_BULLET_COLOR :: Vector4.{0, 0.2, 1, 1};

ENEMY_SPAWN_TIME_THRESHOLD_IN_SECONDS : float64 : 2;
RECOVER_FROM_DMG_TIME_S : float : 0.2;

PARRY_FX_COLOR :: Vector4.{0.01,1,0.1, 1};

VEC2_DOWN :: Vector2.{0, -1};
VEC2_UP :: Vector2.{0, 1};
VEC2_LEFT :: Vector2.{-1, 0};
VEC2_RIGHT :: Vector2.{1, 0};

PLAYER_SWEEP_ANIMATION_TIME :: 0.2;

// We want the bullets to bounce off of each other, so we include the bullet collision mask
ENEMY_BULLET_COLLISION_MASK : EEntityType : .Player | .Bullet;

ENEMY_SHOOT_COOLDOWN_S :: 3.0;

// TBD
PLAYER_SHOOT_COOLDOWN_S :: 1.0;
STAMINA_FADE_THRESHOLD_TIME :: 1.0;

g_shouldQuitGame := false;
g_entities : [2048] Entity;
g_entityIndex := 0;
g_mousePosition: Vector2;
g_currentTime : float64 = 0;
g_timeScale: float = 1;
g_timeScaleCache: float = 1;
g_restoreTimeScaleAfter: float = 0;
g_staminaUnchangedTimer: float = 0;
g_font: *Simp.Dynamic_Font;

g_enemySpawnTimer : float64 = 0;

g_debugMousePtrEntityId := -1;
g_playerId := -1;
g_isPaused := false;
g_scoreBlendTimer : float = 0;
g_score : int = 0;
g_prevScore : int = 0;

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

RAD_TO_DEG :: 180 / PI;

DEG_TO_RAD :: PI / 180;



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

DrawUI :: (delta: float) {
	scoreBlendSpeed : float : 2;
	if (g_scoreBlendTimer > 0) {
		g_scoreBlendTimer -= delta * scoreBlendSpeed;
	}
	displayScore := cast(s32)lerp(cast(float)g_prevScore, cast(float)g_score, 1 - g_scoreBlendTimer);
	healthText := tprint("Score: %", displayScore);
    text_width := Simp.prepare_text(g_font, healthText);

    color  := Vector4.{0.5, 0.8, 0.2, 1};
    Simp.draw_prepared_text(g_font, xx (width / 2), xx (height * 0.9), color);

    if (g_isPaused) {
	    text_width = Simp.prepare_text(g_font, "GAME PAUSED!");
	    Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx (height / 2), color);
	    text_width = Simp.prepare_text(g_font, "Resume");
	    Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx ((height / 2) * 0.9), color);
	    text_width = Simp.prepare_text(g_font, "Quit");
	    Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx ((height / 2) * 0.8), color);
    }
    
}

RestoreTimeScaleSystem :: (unscaledDelta: float) {
	if (g_isPaused) return;
	if (g_restoreTimeScaleAfter > 0) {
		g_restoreTimeScaleAfter -= unscaledDelta;
		return;
	}
	g_timeScale = 1;
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
		enemy.rotation = -atan2(enemy.velocity.x, enemy.velocity.y);
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
	if (entity.type != .Enemy && entity.type != .Player) {
		return;
	}
    barWidth  : float = 60.0;
    barHeight : float = 8.0;

    healthPos := Vector2.{entity.position.x - barWidth / 2.0, entity.position.y + entity.shapeSize + 5.0};

    // Background (dark red)
    DrawRect(healthPos, Vector2.{barWidth, barHeight}, .{0.4, 0.0, 0.0, 1.0});

    healthPct := entity.health / entity.originalHealth;
    DrawRect(healthPos, Vector2.{barWidth * healthPct, barHeight}, .{0.0, 1.0, 0.0, 1.0});
}

DrawStaminaBar :: (entity: *Entity, delta: float) {
	if (entity.type != .Player) {
		return;
	}
	barAlpha : float = 1.0;
	if (g_staminaUnchangedTimer > 0) {
		g_staminaUnchangedTimer -= delta;
	}

	staminaDiff := DEFAULT_PLAYER_STAMINA - entity.stamina;
	if  staminaDiff > 0 {
		entity.stamina +=  delta * STAMINA_PER_BULLET;
		// start fading at X%
		if (staminaDiff > DEFAULT_PLAYER_STAMINA * 0.2) {
			g_staminaUnchangedTimer = STAMINA_FADE_THRESHOLD_TIME;
		}
	}
	barAlpha = lerp(0, 1, g_staminaUnchangedTimer);

    barWidth  : float = 60.0;
    barHeight : float = 8.0;

    healthPos := Vector2.{entity.position.x - barWidth / 2.0, entity.position.y - entity.shapeSize - 5.0};

    // Background (dark red)
    DrawRect(healthPos, Vector2.{barWidth, barHeight}, .{0.0, 0.0, 0.0, barAlpha});

    healthPct := entity.stamina / DEFAULT_PLAYER_STAMINA;
    DrawRect(healthPos, Vector2.{barWidth * healthPct, barHeight}, .{1.0, 1.0, 0.0, barAlpha});
}
	
ApplyMovement :: (entity: *Entity, deltaTime: float) {
	entity.position += entity.velocity * deltaTime * entity.speed;
	entity.rotation += entity.rotationVelocity * deltaTime;

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
    return atan2((b.y - a.y) * DEG_TO_RAD, (b.x - a.x) * DEG_TO_RAD);
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
	if (entity.type != .Enemy || entity.shootCooldownTimer > 0 || !RandChance(1, 3)) return;
	
	shootDir := normalize(g_entities[g_playerId].position - entity.position);
	ShootBullet(entity.position, shootDir, Vector4.{1, 0.01, 0, 1}, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
	entity.shootCooldownTimer = ENEMY_SHOOT_COOLDOWN_S;
}

PlayerShoot :: (entity: *Entity) {
	if (entity.stamina < STAMINA_PER_BULLET) {
		return;
	}
	shootDir := normalize(g_mousePosition - entity.position);
	ShootBullet(entity.position, shootDir, PLAYER_BULLET_COLOR, .Enemy | .Bullet, DEFAULT_BULLET_SPEED);
	entity.stamina -= STAMINA_PER_BULLET;
	g_staminaUnchangedTimer	= STAMINA_FADE_THRESHOLD_TIME;
}

CalculateReflectionVector :: (direction: Vector2, normal: Vector2) -> Vector2 {
	return direction - ((2.0 * dot(direction, normal)) * normal);
}

sign :: (n: float) -> float {
	if n < 0 {
		return -1;
	}
	return 1;
}

IncreaseScore :: (diff: int) {
	if (g_scoreBlendTimer <= 0) {
		g_prevScore = g_score;
		g_scoreBlendTimer = 1;
	}
	g_score += diff;
}
	
HandleCollision :: (first: *Entity, second: *Entity) {
	if (first.type == .Bullet && second.type == .Enemy) {
		second.health -= first.damage;
		// Again, we should probably address entity deletion some day
		first.type = .None;
		second.cacheVelocity = second.velocity;
		second.velocity = first.velocity * 4;
		second.state = .Knockback;
		OnDamaged(second, first);
		return;
	}
	if (first.type == .Player && second.type == .Bullet) {
		if (OnDamaged(first, second)) {
			first.health -= second.damage;
		}
		else {
			g_timeScale = 0.3;
			g_restoreTimeScaleAfter = 0.5;
		}
		second.type = .None;
		return;
	}

	if (first.type == .Bullet && second.type == .Bullet) {
		// Calculate the normal of the collision
		diff := second.position - first.position;
	
	    overlapX := (first.shapeSize + second.shapeSize) - abs(diff.x);
	    overlapY := (first.shapeSize+ second.shapeSize) - abs(diff.y);

	    normal : Vector2;
	    if overlapX < overlapY {
	    	normal = Vector2.{sign(diff.x), 0};
	    }
	    else {
	    	normal = Vector2.{0, sign(diff.y)};
	    }
	
		reflectA := CalculateReflectionVector(first.velocity, normal);
		reflectB := CalculateReflectionVector(second.velocity, normal);
		first.velocity = reflectA;
		second.velocity = reflectB;
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

magnitude :: (v: Vector2) -> float {
    return sqrt(v.x * v.x + v.y * v.y);
}

RotateVec2 :: (vec: Vector2, degrees: float) -> Vector2 {
	length := magnitude(vec);
	newX := vec.x * cos(degrees * DEG_TO_RAD) - vec.y * sin(degrees * DEG_TO_RAD);
	newY := vec.x * sin(degrees * DEG_TO_RAD) - vec.y * cos(degrees * DEG_TO_RAD);
	return Vector2.{newX, newY};
}

OnDamaged :: (entity: *Entity, damageSrc: *Entity) -> bool {
	parryDiff := g_currentTime - entity.parryPressedTime;
	if (parryDiff <= SUCCESSFUL_PARRY_WINDOW_S) {
		// No damage will be applied!
		direction := normalize(damageSrc.position - entity.position);
		ShootBullet(entity.position, direction, PARRY_FX_COLOR, .Enemy, DEFAULT_BULLET_SPEED * 1.5);
		// 45 degree tilted
		ShootBullet(entity.position, RotateVec2(direction, 45), PARRY_FX_COLOR, .Enemy, DEFAULT_BULLET_SPEED * 1.5);
		// -45 degree tilted
		ShootBullet(entity.position, RotateVec2(direction, -45), PARRY_FX_COLOR, .Enemy, DEFAULT_BULLET_SPEED * 1.5);
		PARRY_SCORE_BONUS :: 7;
		IncreaseScore(PARRY_SCORE_BONUS);
		return false;
	}
	entity.cacheColor = entity.color;
	entity.color = Vector4.{1, 0, 0, 1};
	entity.damageAnimTimer = RECOVER_FROM_DMG_TIME_S;
	if (entity.state == .None) {
		entity.state = .Damaged;
	}
	return true;
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
		case .Damaged; return;
		case .Parry; return; // Info only state
		case .Knockback; HandleKnockback(entity, delta);
	}
	
}

HandleAnimations :: (entity: *Entity, delta: float) {
	PARRY_ANIM_SPEED :: 20.0;
	if (entity.parryAnimTimer > 0) {
		// Rotate the entity
		entity.rotation += delta * PARRY_ANIM_SPEED;
		entity.parryAnimTimer -= delta;
	}
}
	
UpdatePlayer :: (entity: *Entity, delta: float) {
	entity.velocity = Vector2.{0, 0};

	if (entity.damageAnimTimer > 0) {
		entity.damageAnimTimer -= delta;
	}

	if (entity.state == .Damaged && entity.damageAnimTimer <= 0) {
		entity.color = DEFAULT_PLAYER_COLOR;
		entity.state = .None;
	}

	if (entity.state == .Parry && entity.parryAnimTimer <= 0) {
		entity.color = DEFAULT_PLAYER_COLOR;
		entity.state = .None;
	}

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
		if event.key_code == .MOUSE_BUTTON_RIGHT && entity.parryAnimTimer <= 0 {
			// Attempt to parry
			entity.parryPressedTime = cast(float)g_currentTime;
			entity.parryAnimTimer = PLAYER_SWEEP_ANIMATION_TIME;
			entity.cacheColor = entity.color;
			entity.state = .Parry;
			entity.color = PARRY_FX_COLOR;
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

	// We do not follow the mouse on animation
	if (entity.parryAnimTimer > 0) {
		return;
	}
	entity.velocity = normalize(entity.velocity);
	mouseDir := normalize(g_mousePosition - entity.position);
	tmpAngle := atan2(mouseDir.x, mouseDir.y);
	entity.rotation = -tmpAngle;
}

HealthSystem :: (entity: *Entity, delta: float) {
	if (entity.type != .Enemy && entity.type != .Player) {
		return;
	}
	
	if (entity.health <= 0) {
		if (entity.type == .Enemy) {
			IncreaseScore(entity.scoreAmount);
		}
		entity.type = .None;
		return;
	}
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

InputSystem :: () {
	for event : events_this_frame {
		if event.type == .QUIT {
			g_shouldQuitGame = true;
		}

		if event.type != .KEYBOARD || !event.key_pressed {
        	break;
	    }
		
        if event.key_code == .ESCAPE {
        	if !g_isPaused {
				g_timeScaleCache = g_timeScale;        		
        		g_timeScale = 0;
        		g_isPaused = true;
        	}
        	else {
        		g_isPaused = false;
		        g_timeScale = g_timeScaleCache;
        	}
        }
	}
}


Update :: () {
    now := seconds_since_init();
    unscaledDelta: float64 = (now - last_time);
    delta : float64 = unscaledDelta * cast(float64)g_timeScale;
    current_dt = cast(float) delta;

    if current_dt > DT_MAX current_dt = DT_MAX;

    last_time = now;

	g_currentTime += delta;
	
	// DebugEntities();


	
	InputSystem();
	
	
	RestoreTimeScaleSystem(cast(float)unscaledDelta);
	
	SpawnEntities(delta);
	for entity : g_entities {
		if (entity.type == .None) continue;
		DrawEntity(*entity);
		DrawHealthBar(*entity, current_dt);
		DrawStaminaBar(*entity, current_dt);

		if (g_isPaused) continue; // Only draw, do not update
		FadeEntityOverTime(*entity, delta);
		CollisionSystem(*entity);
		
		if (entity.type == .Player) {
			UpdatePlayer(*entity, current_dt);
		}
		
		HandleCooldownTimers(*entity, current_dt);
		HandleSpecialStates(*entity, current_dt);
		EnemyShoot(*entity);
		HandleAnimations(*entity, current_dt);
		ApplyMovement(*entity, current_dt);
		HealthSystem(*entity, current_dt);
	}

	DrawUI(current_dt);
}

DEFAULT_ENEMY_SPEED :: 150;
DEFAULT_ENEMY_SIZE_PX :: 25;
DEFAULT_ENEMY_SCORE :: 5;

CreateEnemy :: (position: Vector2) -> Entity {
	result := Entity.{
		position = position,
		speed = DEFAULT_ENEMY_SPEED,
		shape = .Triangle,
		shapeSize = DEFAULT_ENEMY_SIZE_PX,
		color = Vector4.{1, 1, 1, 1},
		health = DEFAULT_ENEMY_HEALTH,
		originalHealth = DEFAULT_ENEMY_HEALTH,
		shootCooldownTimer = ENEMY_SHOOT_COOLDOWN_S,
		scoreAmount = DEFAULT_ENEMY_SCORE,
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

InitResources :: () {
    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);
    g_font = Simp.get_font_at_size("assets/fonts/Nova_Square", "NovaSquare-Regular.ttf", 24);
    if (!g_font) {
    	print("Failed to load font!");
    }
}

main :: () {
	last_time = seconds_since_init();	
	window := create_window(window_name="TotalChaos Remastered", width=width, height=height);	
	// GL.gl_load(*GL.gl);
    Simp.set_render_target(window);
	// create_post_process_resources();
	// GL.glViewport(0, 0, cast(s32)width, cast(s32)height);    
    // Create the player
    player := Entity.{
		type = .Player,
		shape = .Triangle,
		shapeSize = DEFAULT_PLAYER_SIZE_PX,
		color = DEFAULT_PLAYER_COLOR,
		health = DEFAULT_HEALTH * 10, // N hits
		originalHealth = DEFAULT_HEALTH * 10, // N hits
		speed = 500,
		stamina = DEFAULT_PLAYER_STAMINA,
		position = .{width / 2.0, height / 2.0},
	};

	g_playerId = AddEntity(player);
	
	enemy := CreateEnemy(Vector2.{width / 2.0, height / 1.5});
	AddEntity(enemy);

	InitResources();

    while !g_shouldQuitGame {
		reset_temporary_storage();
		update_window_events();	
		mouseX, mouseY := get_mouse_pointer_position();	
        Clamp(*mouseY, 0, height);
        Clamp(*mouseX, 0, width);
		g_mousePosition = Vector2.{cast(float) mouseX, height - cast(float)mouseY};
		
		// GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, scene_fbo);		
		// GL.glViewport(0, 0, cast(u32)width, cast(u32)height);	    
		
		Simp.set_shader_for_color(true);
		// GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, scene_fbo);		

        Simp.clear_render_target(.2, .3, .3, 1);
        Update();

        // render_post_process();
        Simp.swap_buffers(window);
	}
    
}

