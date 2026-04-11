#import "Basic";
#import "Window_Creation";
#import "Input";
#import "Math";
#import "System";
#import "File";
#import "String";
#load "draw_utils.jai";
#load "entity.jai";
#load "random_utils.jai";
#load "queue.jai";
using Sound :: #import "Sound_Player"(VERBOSE = false);

SpawnPoint :: enum u8 {
	Top;
	Bottom;
	Left;
	Right;
}

SLOW_TIME_SCALE :: 0.3;
DEFAULT_PLAYER_COLOR :: Vector4.{3 / 255.0, 211 / 255.0, 252 / 255.0, 1};
DEFAULT_PLAYER_SIZE_PX :: 25;

DEFAULT_BULLET_SPEED : float : 1000; 
DEFAULT_PICKUP_SPEED : float : 100;
PICKUP_LIFETIME :: 10;
DEFAULT_BULLET_DAMAGE : float : 10; 
DEFAULT_HEALTH : float : 10; 
DEFAULT_BULLET_SIZE_PX :: 20;

STAMINA_PER_BULLET :: 30;
DEFAULT_PLAYER_STAMINA :: 100;

SUCCESSFUL_PARRY_WINDOW_S :: 0.3;

DEFAULT_ENEMY_HEALTH :: DEFAULT_HEALTH * 2;
PLAYER_BULLET_COLOR :: Vector4.{0, 0.2, 1, 1};

POWER_UP_COLOR :: Vector4.{250 / 255.0, 180 / 255.0, 30 / 255.0, 1};

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
ENEMY_SHOOT_PREPARATION_S :: 0.5;

// TBD
PLAYER_SHOOT_COOLDOWN_S :: 1.0;
STAMINA_FADE_THRESHOLD_TIME :: 1.0;

ENTITY_MAX_COUNT :: 2048;

g_shouldQuitGame := false;
g_entities : [ENTITY_MAX_COUNT] Entity;
g_availableEntities: Queue(s64);
g_entityIndex := 0;
g_mousePosition: Vector2;
g_currentTime : float64 = 0;
g_timeScale: float = 1;
g_timeScaleCache: float = 1;
g_restoreTimeScaleAfter: float = 0;
g_staminaUnchangedTimer: float = 0;
g_font: *Simp.Dynamic_Font;
g_additionalTexelOffset: float = 1;
g_restoreTexelOffsetAfter: float = 0;

g_sceneTexture: *Simp.Texture;
g_bloomTempPass: *Simp.Texture;
g_window: Window_Type;

g_music: Sound_Data;
g_pauseMusic: Sound_Data;
g_audioStream: *Sound_Stream;
g_pauseStream: *Sound_Stream;

g_enemySpawnTimer : float64 = 0;
g_enemyCount: s32 = 0;

g_debugMousePtrEntityId := -1;
g_playerId := -1;
g_isPaused := false;
g_scoreBlendTimer : float = 0;
g_score : int = 0;
g_prevScore : int = 0;


g_cameraOffset := Vector2.{0, 0};
g_shakeStrength: float = 0;
g_shakeTime: float = 0;

width := 1920;
height := 1080;

MAX_ENEMIES_ON_SCREEN :: 10;

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

SHAKE_MAX_OFFSET :: 20.0;
SHAKE_DECAY      :: 0.05;

UpdateShake :: (delta: float) {
    if g_shakeStrength > 0 {
        g_shakeTime += delta * 20.0;
        g_shakeStrength  =  max(0.0, g_shakeStrength - SHAKE_DECAY * delta);

        magnitude := g_shakeStrength * g_shakeStrength;  // squaring gives nicer feel
        g_cameraOffset.x = sin(g_shakeTime * 1.1) * magnitude * SHAKE_MAX_OFFSET;
        g_cameraOffset.y = cos(g_shakeTime * 0.9) * magnitude * SHAKE_MAX_OFFSET;
    } else {
        g_cameraOffset = .{0, 0};
    }
}

IsGameOver :: () -> bool {
	return g_entities[g_playerId].type == .None;
}
	
DrawEntity :: (entity: *Entity) {
	entitySize := entity.shapeSize * entity.scaleFactor;
	if (entity.shape == .Circle) {
		DrawCircle(entity.position + g_cameraOffset, entitySize, entity.color);
	}
	else if (entity.shape == .Triangle) {
		DrawTriangle(entity.position + g_cameraOffset, entitySize, entity.rotation, entity.color);
	}
	else if (entity.shape == .Square) {
		DrawRect(entity.position + g_cameraOffset, Vector2.{entitySize, entitySize}, entity.color, entity.rotation);
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

DrawPowerUpsUI :: () {
	prevItemPos := Vector2.{ width * 0.1, height * 0.9};
	text: string;
	player : *Entity = *(g_entities[g_playerId]);
	color: Vector4;
	spacing := width * 0.05;
	if (player.flags & .HasBomb) {
		text = tprint("BOMB: AVAILABLE");
		color = Vector4.{0, 1.0, 0.1, 1.0};
	}
	else {
		text = tprint("BOMB: N/A");
		color = Vector4.{1.0, 0.0, 0.1, 1.0};
	}
    text_width := Simp.prepare_text(g_font, text);

    Simp.draw_prepared_text(g_font, xx prevItemPos.x, xx prevItemPos.y, color);
    prevItemPos.x += text_width + spacing;

	if (player.flags & .HasShield) {
		text = tprint("SHIELD: AVAILABLE");
		color = Vector4.{0, 1.0, 0.1, 1.0};
	}
	else {
		text = tprint("SHIELD: N/A");
		color = Vector4.{1.0, 0.0, 0.1, 1.0};
	}
    text_width = Simp.prepare_text(g_font, text);
    Simp.draw_prepared_text(g_font, xx prevItemPos.x, xx prevItemPos.y, color);
    prevItemPos.x += text_width + spacing;
	
	if (player.flags & .HasShield) {
		text = tprint("SPLIT_BULLET: ON");
		color = Vector4.{0, 1.0, 0.1, 1.0};
	}
	else {
		text = tprint("SPLIT_BULLET: N/A");
		color = Vector4.{1.0, 0.0, 0.1, 1.0};
	}
    text_width = Simp.prepare_text(g_font, text);
    Simp.draw_prepared_text(g_font, xx prevItemPos.x, xx prevItemPos.y, color);
    prevItemPos.x += text_width + spacing;
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
    
	DrawPowerUpsUI();
 
    if (IsGameOver()) {
	    text_width = Simp.prepare_text(g_font, "GAME OVER!");
	    Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx (height / 2), color);
    	return;
    }

    if (g_isPaused) {
	    text_width = Simp.prepare_text(g_font, "GAME PAUSED!");
	    Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx (height / 2), color);
	    text_width = Simp.prepare_text(g_font, "Resume");
	    Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx ((height / 2) * 0.9), color);
	    text_width = Simp.prepare_text(g_font, "Quit");
	    Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx ((height / 2) * 0.8), color);

	    g_audioStream.user_flags |= .PAUSED_DUE_TO_MENU;
        g_audioStream.current_rate = 0;

        if (g_pauseStream.user_flags & .PAUSED_DUE_TO_MENU) {
	    	g_pauseStream.current_rate = g_audioStream.desired_rate;
	        g_pauseStream.user_flags &= ~.PAUSED_DUE_TO_MENU;
        }
        
    }
    else if (g_audioStream.user_flags & .PAUSED_DUE_TO_MENU) {
    	g_audioStream.current_rate = g_audioStream.desired_rate;
        g_audioStream.user_flags &= ~.PAUSED_DUE_TO_MENU;

	    g_pauseStream.user_flags |= .PAUSED_DUE_TO_MENU;
	    g_pauseStream.current_rate = 0;
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

RestoreTexelOffsetSystem :: (delta: float) {
	if (g_isPaused) return;
	if (g_restoreTexelOffsetAfter > 0) {
		g_restoreTexelOffsetAfter -= delta;
		return;
	}
	g_additionalTexelOffset = 1;
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
	if (g_enemyCount < MAX_ENEMIES_ON_SCREEN && g_enemySpawnTimer >= ENEMY_SPAWN_TIME_THRESHOLD_IN_SECONDS && RandChance(1, 2)) {
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
		flags = .HasLifetime,
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

ShootShard :: (position: Vector2, shootDir: Vector2) {
	bullet := Entity.{
		type = .Bullet,
		position = position,
		speed = DEFAULT_BULLET_SPEED * 0.2,
		shape = .Square,
		flags = .HasLifetime,
		shapeSize = DEFAULT_BULLET_SIZE_PX * 1.5,
		color = Vector4.{0, 1, 0, 1},
		damage = DEFAULT_BULLET_DAMAGE,
		velocity = shootDir,
		rotationVelocity = 2,
		initialLifetime = 3,
		remainingLifetime = 3,
		collisionMask = .Enemy
	};
	
	AddEntity(bullet);
}

EnemyDeathParticleVFX :: (position: Vector2, shootDir: Vector2) {
	bullet := Entity.{
		type = .VFX,
		position = position,
		speed = DEFAULT_BULLET_SPEED * 0.05,
		shape = .Triangle,
		flags = .HasLifetime,
		shapeSize = DEFAULT_BULLET_SIZE_PX,
		color = Vector4.{0.3, 0.3, 0.3, 1},
		velocity = shootDir,
		rotationVelocity = 3,
		initialLifetime = 1,
		remainingLifetime = 1,
		collisionMask = .None
	};
	
	AddEntity(bullet);
}

BulletCollisionParticleVFX :: (position: Vector2, shootDir: Vector2) {
	bullet := Entity.{
		type = .VFX,
		position = position,
		speed = DEFAULT_BULLET_SPEED * 0.05,
		shape = .Circle,
		flags = .HasLifetime,
		shapeSize = DEFAULT_BULLET_SIZE_PX * 0.2,
		color = Vector4.{0.8, 0.9, 0.4, 1},
		velocity = shootDir,
		// rotationVelocity = 3,
		initialLifetime = 1,
		remainingLifetime = 1,
		collisionMask = .None
	};
	
	AddEntity(bullet);
}


ConeVFX :: (position: Vector2, direction: Vector2, coneAngle: float = 60.0, particleCount: int = 3) {
    halfCone := coneAngle / 2.0;
    step := coneAngle / cast(float)(particleCount - 1);

    for i : 0..particleCount - 1 {
        angleOffset := -halfCone + step * cast(float)i;
        shootDir := RotateVec2(direction, angleOffset + RandFloatInRange(-45.0, 45.0));
        
		bullet := Entity.{
			type = .VFX,
			position = position,
			speed = DEFAULT_BULLET_SPEED * 0.05,
			shape = .Square,
			flags = .HasLifetime | .DecreaseSizeOverLifeTime,
			shapeSize = DEFAULT_BULLET_SIZE_PX * 0.5,
			color = Vector4.{0.9, 0.9, 0.4, 1},
			velocity = -shootDir,
			rotationVelocity = 3,
			initialLifetime = 1,
			remainingLifetime = 1,
			collisionMask = .None
		};
		AddEntity(bullet);
    }
}

EnemyShoot :: (entity: *Entity, delta: float) {
	// Get the direction of the player
	if (entity.type != .Enemy) return;

	if (entity.shootAnimTimer > 0) {
		entity.shootAnimTimer -= delta;

		// Lerp towards orange
		entity.color = lerp(entity.cacheColor, Vector4.{0.969, 0.39, 0.15, 1}, entity.shootAnimTimer / ENEMY_SHOOT_PREPARATION_S);
		entity.color.w = 1.0;
		
		if (entity.shootAnimTimer <= 0) {
			if (entity.flags & .CanMultiShoot) {
				SHOOT_POS_OFFSET :: 20.0;
				ShootBullet(entity.position + (VEC2_RIGHT * SHOOT_POS_OFFSET), VEC2_RIGHT, Vector4.{1, 0.01, 0, 1}, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
				ShootBullet(entity.position + (VEC2_LEFT * SHOOT_POS_OFFSET), VEC2_LEFT, Vector4.{1, 0.01, 0, 1}, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
				ShootBullet(entity.position + (VEC2_UP * SHOOT_POS_OFFSET), VEC2_UP, Vector4.{1, 0.01, 0, 1}, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
				ShootBullet(entity.position + (VEC2_DOWN * SHOOT_POS_OFFSET), VEC2_DOWN, Vector4.{1, 0.01, 0, 1}, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
			}
			else {
				shootDir := normalize(g_entities[g_playerId].position - entity.position);
				ShootBullet(entity.position, shootDir, Vector4.{1, 0.01, 0, 1}, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
			}
			entity.shootCooldownTimer = ENEMY_SHOOT_COOLDOWN_S;
			entity.color = Vector4.{1, 1, 1, 1}; // Default enemy color
		}
		
		return;
	}
	
	if (entity.shootCooldownTimer > 0 || !RandChance(1, 3)) return;

	// Prepare to shoot
	entity.shootAnimTimer = ENEMY_SHOOT_PREPARATION_S;
	entity.cacheColor = entity.color;
	
}

PlayerShoot :: (entity: *Entity) {
	if (entity.stamina < STAMINA_PER_BULLET) {
		return;
	}
	shootDir := normalize(g_mousePosition - entity.position);
	ShootBullet(entity.position, shootDir, PLAYER_BULLET_COLOR, .Enemy | .Bullet, DEFAULT_BULLET_SPEED * 1.5);
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
	if (IsGameOver()) return;
	g_score += diff;
}
	
HandleCollision :: (first: *Entity, second: *Entity) {
	if (first.type == .Bullet && second.type == .Enemy) {
		second.health -= first.damage;
		// Again, we should probably address entity deletion some day
		second.cacheVelocity = second.velocity;
		second.velocity = first.velocity * 4;
		second.state = .Knockback;
		OnDamaged(second, first);
		RemoveEntity(first);
		for i : 0..6 {
			BulletCollisionParticleVFX(first.position, RotateVec2(first.velocity, i * 60.0));
		}
		return;
	}
	if (first.type == .Player && second.type == .Bullet) {
		if (OnDamaged(first, second)) {
			first.health -= second.damage;
			g_shakeStrength = 0.5;
			g_additionalTexelOffset = 3.0;
			g_restoreTexelOffsetAfter = 0.2;
			for i : 0..6 {
				BulletCollisionParticleVFX(second.position, RotateVec2(second.velocity, i * 60.0));
			}
		}
		else {
			g_timeScale = SLOW_TIME_SCALE;
			g_restoreTimeScaleAfter = 0.5;
		}
		RemoveEntity(second);
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

	if (first.type == .Pickup && second.type == .Player) {
		if (AddPowerUps(first.flags, second)) {
			// Do some sound effect
		}
		RemoveEntity(first);
	}
}

CalcPowerUpsBitmask :: () -> EEntityFlags {
	mask : u16 = 0;
	baseLine: u16 = 1;
	start := EEntityFlags.PowerUpBeginNumber;
	end := EEntityFlags.PowerUpEndNumber;
	for i : start..end {
		mask |= (baseLine << i);
	}

	return cast(EEntityFlags)mask;
}

AddPowerUps :: (pickupFlags: EEntityFlags, playerEntity: *Entity) -> bool {
	PowerUpsBitmask :: #run CalcPowerUpsBitmask();

	cleanFlags := pickupFlags & PowerUpsBitmask;
	print("Picked up power up with value: %s\n", cleanFlags);
	playerEntity.flags |= cleanFlags;
	return cleanFlags != 0;
}

DropLoot :: (position: Vector2) {
	powerUpSelectN := RandIntInRange(xx EEntityFlags.PowerUpBeginNumber, xx EEntityFlags.PowerUpEndNumber);

	powerUpSelectReal := cast(EEntityFlags)(1 << (powerUpSelectN - 1)); // yields the value of the flags
	
	entity := Entity.{
		color = POWER_UP_COLOR,
		shape = .Square,
		shapeSize = DEFAULT_ENEMY_SIZE_PX,
		position = position,
		velocity = normalize(RandVec2(Vector2.{0,0}, Vector2.{1,1})),
		rotationVelocity = DEFAULT_PICKUP_SPEED,
		speed = DEFAULT_PICKUP_SPEED,
		flags = powerUpSelectReal | .HasLifetime,
		initialLifetime = PICKUP_LIFETIME,
		remainingLifetime = PICKUP_LIFETIME,
		collisionMask = .Player,
		type = .Pickup
	};
	AddEntity(entity);
	print("Dropped loot with value: %\n", powerUpSelectReal);
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
	entity.color = Vector4.{1, 1, 1, 1};
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

	if (entity.velocity != Vector2.{0, 0}) {
		// Draw a trail in a cone
		ConeVFX(entity.position - (entity.velocity * 10), entity.velocity);		
	}
}

HealthSystem :: (entity: *Entity, delta: float) {
	if (entity.type != .Enemy && entity.type != .Player) {
		return;
	}

	if (entity.health <= 0) {
		if (entity.type == .Enemy) {
			IncreaseScore(entity.scoreAmount);

			if (RandChance(1, 10)) {
				DropLoot(entity.position);
			}

			// Normal animation
			if (entity.flags & .ExplodeOnDeath) {
				g_timeScale = SLOW_TIME_SCALE;
				g_restoreTimeScaleAfter = 0.5;
				for i : 0..12 {
					ShootShard(entity.position, RotateVec2(entity.velocity, cast(float)i * 30.0));
				}
			}
			else {
				for i : 0..6 {
					EnemyDeathParticleVFX(entity.position, RotateVec2(entity.velocity, RandFloatInRange(0, 360)));
				}
			}
			g_enemyCount -= 1;
		}
		RemoveEntity(entity);
		return;
	}
}

FadeEntityOverTime :: (entity: *Entity, delta: float64) {
	if !(entity.flags & .HasLifetime) {
		return;
	}
	if (entity.remainingLifetime <= 0) {
		RemoveEntity(entity);
	}

	entity.remainingLifetime -= cast(float)delta;
	// Fade the color's opacity
	lerpingBlend := entity.remainingLifetime / entity.initialLifetime;
	entity.color.w = lerp(0.1, 1.0, lerpingBlend);
	// entity.shapeSize = lerp(5, DEFAULT_BULLET_SIZE_PX, lerpingBlend);
}

DecreaseEntitySizeOverTime :: (entity: *Entity, delta: float64) {
	if !(entity.flags & .DecreaseSizeOverLifeTime) {
		return;
	}
	
	if (entity.remainingLifetime <= 0) {
		RemoveEntity(entity);
	}

	entity.remainingLifetime -= cast(float)delta;
	// Fade the color's opacity
	lerpingBlend := entity.remainingLifetime / entity.initialLifetime;
	entity.scaleFactor = lerp(0.0, 1.0, lerpingBlend);
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
	RestoreTexelOffsetSystem(current_dt);

	SpawnEntities(delta);
	for entity : g_entities {
		if (IsGameOver()) {
			g_timeScale = 0.1;
			g_additionalTexelOffset = 10.0;
		}
		if (entity.type == .None) continue;
		UpdateShake(current_dt);
		DrawEntity(*entity);
		DrawHealthBar(*entity, current_dt);
		DrawStaminaBar(*entity, current_dt);

		if (g_isPaused) continue; // Only draw, do not update
		FadeEntityOverTime(*entity, delta);
		DecreaseEntitySizeOverTime(*entity, delta);
		CollisionSystem(*entity);
		
		if (entity.type == .Player) {
			UpdatePlayer(*entity, current_dt);
		}
		
		HandleCooldownTimers(*entity, current_dt);
		HandleSpecialStates(*entity, current_dt);
		EnemyShoot(*entity, current_dt);
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
	shape := EShape.Triangle;
	flags := EEntityFlags.None;
	health := DEFAULT_ENEMY_HEALTH;
	if (RandChance(1, 7)) {
		// Creates an AOE enemy
		flags |= .CanMultiShoot | .ExplodeOnDeath;
		shape = .Square;
		health *= 2;
	}
	result := Entity.{
		position = position,
		speed = DEFAULT_ENEMY_SPEED,
		shape = shape,
		shapeSize = DEFAULT_ENEMY_SIZE_PX,
		color = Vector4.{1, 1, 1, 1},
		health = health,
		originalHealth = health,
		shootCooldownTimer = ENEMY_SHOOT_COOLDOWN_S,
		scoreAmount = DEFAULT_ENEMY_SCORE,
		flags = flags,
		type = .Enemy
	};
	g_enemyCount += 1;
	return result;
}

AddEntity :: (entity: Entity) -> s64 {
	success, retVal := Dequeue(*g_availableEntities);
	g_entities[retVal] = entity;
	g_entities[retVal].scaleFactor = 1; // Always initialize the scale to 1
	g_entities[retVal].id = retVal;
	return retVal;
}

RemoveEntity :: (entity: *Entity) {
	// Prevent double free
	if (entity.type == .None) {
		return;
	}
	// We set its type to none and return its id to the available pool
	entity.type = .None;
	Enqueue(*g_availableEntities, entity.id);
}

InitResources :: () {
    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);
    g_music = load_audio_file("assets/audio/Contact_Trimmed.wav");
    if (!g_music.loaded) {
    	print("Failed to load music!");
    	exit(1);
    }
    
    devices := get_devices();
    success := sound_player_init(.{});
    assert(success);

    g_audioStream = make_stream(*g_music, .MUSIC);
    set_repeating(g_audioStream, true);
    g_audioStream.user_volume_scale = 0.5;
    
    start_playing(g_audioStream);
    
    g_pauseMusic = load_audio_file("assets/audio/Rtho_LowPass.wav");
    g_pauseStream = make_stream(*g_pauseMusic, .MUSIC);
    set_repeating(g_pauseStream, true);
    start_playing(g_pauseStream);

    g_pauseStream.user_flags |= .PAUSED_DUE_TO_MENU;
    g_pauseStream.current_rate = 0;

    g_font = Simp.get_font_at_size("assets/fonts/Nova_Square", "NovaSquare-Regular.ttf", 24);
    if (!g_font) {
    	print("Failed to load font!");
    	exit(1);
    }
}

InitRenderingPipeline :: () {
    Simp.set_render_target(g_window);
    Simp.clear_render_target(.15, .08, .08, 1);
	g_sceneTexture = Simp.texture_create_render_target(xx width, xx height, .RGBA8);
	g_bloomTempPass = Simp.texture_create_render_target(xx width, xx height, .RGBA8);
}

DrawFrameBegin :: () {
	// Draw the scene to the texture
	Simp.set_render_target(g_sceneTexture);
	Simp.set_shader_for_color(true);
    Simp.clear_render_target(.0, .01, .03, 1);
    
}

DrawFrameEnd :: () {
	Simp.set_render_target(g_bloomTempPass);
    Simp.clear_render_target(0, 0, 0, 0);

    Simp.set_shader_for_images(g_sceneTexture);
    Simp.set_uniform_float_for_images("pass_direction", 1.0);
    Simp.set_uniform_float_for_images("additional_offset", g_additionalTexelOffset);

    Simp.immediate_quad(0, 0, xx width, xx height, Vector4.{1,1,1,1});	
    Simp.set_render_target(g_window);
    Simp.clear_render_target(.0, .01, .03, 1);

	Simp.set_shader_for_images(g_sceneTexture);
	Simp.set_uniform_float_for_images("pass_direction", 0.0);
	Simp.set_uniform_float_for_images("additional_offset", g_additionalTexelOffset);
    Simp.immediate_quad(0, 0, xx width, xx height, Vector4.{1,1,1,1});
}

InitGame :: () {
    // Initialize our entity storage
	InitQueue(*g_availableEntities, ENTITY_MAX_COUNT);
    
	for idx : 0..ENTITY_MAX_COUNT - 1 {
		Enqueue(*g_availableEntities, idx);
	}
        
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
	
}

main :: () {
	last_time = seconds_since_init();	
	g_window = create_window(window_name="TotalChaos Remastered", width=width, height=height);	

	InitRenderingPipeline();
	InitResources();
	InitGame();

    while !g_shouldQuitGame {
		reset_temporary_storage();
		update_window_events();	
		mouseX, mouseY := get_mouse_pointer_position();	
        Clamp(*mouseY, 0, height);
        Clamp(*mouseX, 0, width);
		g_mousePosition = Vector2.{cast(float) mouseX, height - cast(float)mouseY};
	
		DrawFrameBegin();
        Update();
        DrawFrameEnd();

        // render_post_process();
        Sound.update();
        Simp.swap_buffers(g_window);
	}

	sound_player_shutdown();
    
}

