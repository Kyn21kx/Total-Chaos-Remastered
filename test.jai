#import "Basic";
#import "Window_Creation";
// using tracy :: #import "tracy"(IMPORT_MODE = .CLIENT, ENABLED = false);
#import "Input";
#import "Math";
#import "System";
#import "File";
#import "String";
#load "draw_utils.jai";
#load "entity.jai";
#load "random_utils.jai";
#load "queue.jai";
#load "shapes3d.jai";
#load "augments.jai";
#load "spatial_grid.jai";
using Sound :: #import "Sound_Player"(VERBOSE = false);

SpawnPoint :: enum u8 {
	Top;
	Bottom;
	Left;
	Right;
}


EMouseButtonState :: enum u8 {
	None :: 0;
	MousePressedLeft :: 1;
	MousePressedRight :: 2;
	SpacePressed :: 4;
}

SLOW_TIME_SCALE :: 0.3;
DEFAULT_PLAYER_COLOR :: Vector4.{3 / 255.0, 211 / 255.0, 252 / 255.0, 1};
DEFAULT_PLAYER_SIZE_PX :: 25;
ENEMY_BULLET_COLOR :: Vector4.{1, 0.01, 0, 1};

ENTITY_MAX_SPEED :: 2000;
SHIELD_HEALTH :: 3;
BOMB_RADIUS :: 600;
DEFAULT_BULLET_SPEED : float : 1000; 
DEFAULT_PICKUP_SPEED : float : 100;
PICKUP_LIFETIME :: 10;
DEFAULT_BULLET_DAMAGE : float : 10; 
DEFAULT_HEALTH : float : 10; 
DEFAULT_BULLET_SIZE_PX :: 20;
DEFAULT_BLACK_HOLE_SIZE_PX :: 200;

STAMINA_PER_BULLET :: 30;
DEFAULT_PLAYER_STAMINA :: 100;

SUCCESSFUL_PARRY_WINDOW_S :: 0.15;

DEFAULT_ENEMY_HEALTH :: DEFAULT_HEALTH * 2;
PLAYER_BULLET_COLOR :: Vector4.{0, 0.2, 1, 1};

POWER_UP_COLOR :: Vector4.{250 / 255.0, 180 / 255.0, 30 / 255.0, 1};

ENEMY_SPAWN_TIME_THRESHOLD_IN_SECONDS : float64 : 2;
RECOVER_FROM_DMG_TIME_S : float : 0.2;

PARRY_FX_COLOR :: Vector4.{0.01,1,0.1, 1};

VEC3_DOWN :: Vector3.{0, -1, 0};
VEC3_UP :: Vector3.{0, 1, 0};
VEC3_LEFT :: Vector3.{-1, 0, 0};
VEC3_RIGHT :: Vector3.{1, 0, 0};

PLAYER_SWEEP_ANIMATION_TIME :: 0.2;

// We want the bullets to bounce off of each other, so we include the bullet collision mask
ENEMY_BULLET_COLLISION_MASK : EEntityType : .Player | .Bullet | .Shield;

ENEMY_SHOOT_COOLDOWN_S :: 3.0;
ENEMY_SHOOT_PREPARATION_S :: 0.5;

// TBD
PLAYER_SHOOT_COOLDOWN_S :: 1.0;
STAMINA_FADE_THRESHOLD_TIME :: 1.0;
SPLIT_BULLET_COUNT :: 5;

ENTITY_MAX_COUNT : u64 : 2048;

BLACK_HOLE_MAX_COUNT :: 10;

DEFAULT_TEXEL_OFFSET :: 1.5;

g_shouldQuitGame := false;
g_entities : [ENTITY_MAX_COUNT] Entity;
// Small subset of the entities to check for black holes to avoid looping all entities to find a black hole
g_blackHoleCache: [BLACK_HOLE_MAX_COUNT] u64;
g_spatialGrid: SpatialHashGrid;
g_availableEntities: Queue(u64);
g_mousePosition: Vector2;
g_inputStateThisFrame: EMouseButtonState = .None;
g_currentTime : float64 = 0;
g_timeScale: float = 1;
g_timeScaleCache: float = 1;
g_restoreTimeScaleAfter: float = 0;
g_staminaUnchangedTimer: float = 0;
g_splitBulletsLeft: int = 0;
g_font: *Simp.Dynamic_Font;
g_additionalTexelOffset: float = DEFAULT_TEXEL_OFFSET;
g_restoreTexelOffsetAfter: float = 0;

CHAOS_PER_KILL :: 0.05;
CHAOS_PER_BOMB :: 0.1;
CHAOS_PER_BOUNCE :: 0.001;
CHAOS_PER_PARRY :: 0.1;
CHAOS_DEPLETE_WAIT_TIME :: 1;
CHAOS_DEPLETE_SPEED :: 0.05;
CHAOS_PENALTY_ON_DMG :: 0.1;

CHAOS_MULT_PER_BULLET :: 0.01;

g_chaosDepleteTimer: float = 0;
g_chaosMultiplier: float = 1;
g_chaosPercentage: float = 0;
g_chaosPercentagePrev: float = 0;
g_chaosModeDuration: float = 0;

g_sceneTexture: *Simp.Texture;
g_bloomTempPass: *Simp.Texture;
g_window: Window_Type;

g_music: Sound_Data;
g_pauseMusic: Sound_Data;
g_audioStream: *Sound_Stream;
g_pauseStream: *Sound_Stream;

g_enemySpawnTimer : float64 = 0;
g_enemyCount: s32 = 0;

g_waveNumber : s32 = 1;
g_enemiesKilledThisWave : s32 = 0;
g_enemiesToKillThisWave : s32 = 5;
g_waveAnnouncementTimer : float = 0;
g_newWaveCountdownTimer : float = 0;
g_enemiesSpawnedThisWave : s32 = 0;
g_isWaveCleared : bool = false;
g_newWaveAnnouncement : bool = false;

WAVE_BASE_ENEMIES_PER_WAVE :: 10;
WAVE_MAX_ENEMIES_PER_WAVE :: 50;
WAVE_ENEMIES_INCREMENT :: 3;
WAVE_BASE_SPAWN_INTERVAL :: 2.0;
WAVE_MIN_SPAWN_INTERVAL :: 0.3;
WAVE_SPAWN_INTERVAL_DECREASE :: 0.1;
WAVE_BASE_ENEMY_SPEED_MULT :: 1.0;
WAVE_MAX_ENEMY_SPEED_MULT :: 3.0;
WAVE_SPEED_INCREMENT :: 0.15;
WAVE_BASE_ENEMY_HEALTH_MULT :: 1.0;
WAVE_MAX_ENEMY_HEALTH_MULT :: 5.0;
WAVE_HEALTH_INCREMENT :: 0.2;
WAVE_CLEAR_DISPLAY_TIME :: 2.0;
WAVE_NEW_WAVE_COUNTDOWN :: 3.0;

// Entities we need to keep a constant reference to
g_debugMousePtrEntityId : u64 = 0;
g_playerId : u64 = 0;
g_bombHolderId : u64 = 0;

g_isPaused := false;
g_scoreBlendTimer : float = 0;
g_score : int = 0;
g_prevScore : int = 0;


g_cameraOffset := Vector3.{0, 0, 0};
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

ToVec3 :: (v: Vector2) -> Vector3 {
	return .{v.x, v.y, 0};
}

ToVec2 :: (v: Vector3) -> Vector2 {
	return .{v.x, v.y};
}

UpdateShake :: (delta: float) {
// 	tracy.ZoneScoped();
    if g_shakeStrength > 0 {
        g_shakeTime += delta * 20.0;
        g_shakeStrength  =  max(0.0, g_shakeStrength - SHAKE_DECAY * delta);

        magnitude := g_shakeStrength * g_shakeStrength; // squaring gives nicer feel
        g_cameraOffset.x = sin(g_shakeTime * 1.1) * magnitude * SHAKE_MAX_OFFSET;
        g_cameraOffset.y = cos(g_shakeTime * 0.9) * magnitude * SHAKE_MAX_OFFSET;
    } else {
        g_cameraOffset = .{0, 0, 0};
    }
}

IsGameOver :: () -> bool {
	return g_entities[g_playerId].type == .None;
}

UpdateCollisionCache :: (p_entities: [] Entity) {
// 	tracy.ZoneScoped();
	for *bucket : g_collisionCache {
		array_reset_keeping_memory(bucket);
	}
	// We can also use the same loop to re-reserve our spatial grid
	SpatialClear(*g_spatialGrid);

	for *entity : p_entities {
		// Collision layer is not applied to this entity
		if (entity.type & EEntityType.CollisionEnabledLayer) == 0 {
			continue;
		}
		// Get the bit where it belongs
		index := ExtractBitIndex(cast(u64)entity.type);
		array_add(*(g_collisionCache[index]), entity.id);
		SpatialRegisterEntityAt(*g_spatialGrid, entity.id, entity.position);
	}
}
	
DrawEntity :: (entity: *Entity) {
// 	tracy.ZoneScoped();
	entitySize := entity.shapeSize * entity.scaleFactor;
	if (entity.shape == .Circle) {
		DrawCircle(ToVec2(entity.position + g_cameraOffset), entitySize, entity.color);
	}
	else if (entity.shape == .Triangle) {
		DrawTriangle(ToVec2(entity.position + g_cameraOffset), entitySize, entity.rotation, entity.color);
	}
	else if (entity.shape == .Square) {
		DrawRect(ToVec2(entity.position + g_cameraOffset), Vector2.{entitySize, entitySize}, entity.color, entity.rotation);
	}
	else if (entity.shape == .GradientCircle) {
		DrawGradientCircle(ToVec2(entity.position + g_cameraOffset), entitySize, entity.color);
	}
	else if (entity.shape == .Star) {
		DrawStar(ToVec2(entity.position + g_cameraOffset), entitySize, entitySize * 0.3, color = entity.color);
	}
}

GetCurrentWaveSpawnInterval :: () -> float64 {
    interval := WAVE_BASE_SPAWN_INTERVAL - (cast(float64)(g_waveNumber - 1) * WAVE_SPAWN_INTERVAL_DECREASE);
    return max(interval, WAVE_MIN_SPAWN_INTERVAL);
}

GetCurrentWaveEnemySpeedMult :: () -> float {
    mult := WAVE_BASE_ENEMY_SPEED_MULT + (cast(float)(g_waveNumber - 1) * WAVE_SPEED_INCREMENT);
    return min(mult, WAVE_MAX_ENEMY_SPEED_MULT);
}

GetCurrentWaveEnemyHealthMult :: () -> float {
    mult := WAVE_BASE_ENEMY_HEALTH_MULT + (cast(float)(g_waveNumber - 1) * WAVE_HEALTH_INCREMENT);
    return min(mult, WAVE_MAX_ENEMY_HEALTH_MULT);
}

GetEnemiesPerWave :: () -> s32 {
    count := WAVE_BASE_ENEMIES_PER_WAVE + ((g_waveNumber - 1) * WAVE_ENEMIES_INCREMENT);
    return min(count, WAVE_MAX_ENEMIES_PER_WAVE);
}

StartNewWave :: () {
    g_waveNumber += 1;
    g_enemiesToKillThisWave = GetEnemiesPerWave();
    g_enemiesKilledThisWave = 0;
    g_enemiesSpawnedThisWave = 0;
    g_isWaveCleared = false;
    g_newWaveAnnouncement = true;
    g_newWaveCountdownTimer = WAVE_NEW_WAVE_COUNTDOWN;
    g_waveAnnouncementTimer = WAVE_NEW_WAVE_COUNTDOWN + WAVE_CLEAR_DISPLAY_TIME;
}

CheckWaveCompletion :: () {
// 	tracy.ZoneScoped();
    if (g_isWaveCleared || g_newWaveAnnouncement) return;
    
    if (g_enemiesKilledThisWave >= g_enemiesToKillThisWave) {
        g_isWaveCleared = true;
        g_waveAnnouncementTimer = WAVE_CLEAR_DISPLAY_TIME;
        print("Wave % Complete!\n", g_waveNumber);
    }
}

CalculateRandomSpawnPoint :: (outSpawnPoint: *SpawnPoint) -> Vector3 {
// 	tracy.ZoneScoped();
	spotNumericMin := cast(u8)SpawnPoint.Top;
	spotNumericMax := (cast(u8)SpawnPoint.Right) + 1;
	<< outSpawnPoint = cast(SpawnPoint)RandIntInRange(spotNumericMin, spotNumericMax);

	if #complete << outSpawnPoint == {
		case .Top; return ToVec3(RandVec2(ScreenUpperLeft(), ScreenUpperRight()));
		case .Bottom; return ToVec3(RandVec2(ScreenLowerLeft(), ScreenLowerRight()));
		case .Left; return ToVec3(RandVec2(ScreenLowerLeft(), ScreenUpperLeft()));
		case .Right; return ToVec3(RandVec2(ScreenLowerRight(), ScreenUpperRight()));
	}
}

DrawPowerUpsUI :: () {
// 	tracy.ZoneScoped();
	prevItemPos := Vector2.{ width * 0.33, height * 0.9};
	text: string;
	player : *Entity = *(g_entities[g_playerId]);
	color: Vector4;
	spacing := width * 0.05;
	if (player.flags & .HasBomb) {
		text = tprint("BOMB: [SPACE]");
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
	
	if (player.flags & .HasSplitBullet) {
		text = tprint("SPLIT_BULLET: %", g_splitBulletsLeft);
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
// 	tracy.ZoneScoped();
	scoreBlendSpeed : float : 2;
	if (g_scoreBlendTimer > 0) {
		g_scoreBlendTimer -= delta * scoreBlendSpeed;
	}
	displayScore := cast(s32)lerp(cast(float)g_prevScore, cast(float)g_score, 1 - g_scoreBlendTimer);
    
    color  := Vector4.{0.5, 0.8, 0.2, 1};
    
    waveText := tprint("Wave: %", g_waveNumber);
    text_width := Simp.prepare_text(g_font, waveText);
    Simp.draw_prepared_text(g_font, xx (width * 0.05), xx (height * 0.95), color);
    
    killsText := tprint("Kills: %/%", g_enemiesKilledThisWave, g_enemiesToKillThisWave);
    text_width = Simp.prepare_text(g_font, killsText);
    Simp.draw_prepared_text(g_font, xx (width * 0.05), xx (height * 0.92), color);
    
	healthText := tprint("Score: %", displayScore);
    text_width = Simp.prepare_text(g_font, healthText);
    Simp.draw_prepared_text(g_font, xx (width / 2), xx (height * 0.95), color);

    screenCenter := Vector2.{xx (width / 2), xx (height / 2)};

    DrawChaosModeBar(delta);
    
    if (g_waveAnnouncementTimer > 0 && !g_isPaused) {
        if (g_newWaveAnnouncement) {
            announceText := tprint("Wave %!", g_waveNumber);
            text_width = Simp.prepare_text(g_font, announceText);
            Simp.draw_prepared_text(g_font, xx screenCenter.x - (text_width / 2), xx (height / 2), Vector4.{1, 1, 0, 1});
            
            countdownText := tprint("Starting in %...", cast(s32)ceil(g_newWaveCountdownTimer));
            text_width = Simp.prepare_text(g_font, countdownText);
            Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx (height / 2) - 30, Vector4.{0.8, 0.8, 0.8, 1});
            
            enemiesText := tprint("Enemies to kill: %", g_enemiesToKillThisWave);
            text_width = Simp.prepare_text(g_font, enemiesText);
            Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx (height / 2) - 60, Vector4.{0.6, 0.6, 0.6, 1});
        }
        else if (g_isWaveCleared) {
            clearedText := tprint("Wave % Cleared!", g_waveNumber);
            text_width = Simp.prepare_text(g_font, clearedText);
            Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx (height / 2), Vector4.{0, 1, 0.5, 1});
        }
    }
    
	DrawPowerUpsUI();
 
    if (IsGameOver()) {
	    text_width = Simp.prepare_text(g_font, "GAME OVER!");
	    gameOverPos := Vector2.{xx (screenCenter.x - (text_width / 2)), screenCenter.y};
	    Simp.draw_prepared_text(g_font, xx gameOverPos.x, xx gameOverPos.y, color);

	    color = Vector4.{1, 1, 1, 1.0};

	    restartPos := screenCenter;
	    restartPos.y += VEC3_DOWN.y * (height * 0.1);
	    restartPos.x += VEC3_LEFT.x * (width * 0.1);
	    
	    text_width = Simp.prepare_text(g_font, "[Restart]");
	    disToRestart := magnitude(restartPos - g_mousePosition);
	    if (disToRestart <= xx text_width) {
	    	color = PARRY_FX_COLOR;
	    	if (g_inputStateThisFrame & .MousePressedLeft) {
	    		// Restart the game
	    		InitGame();
	    	}
	    }
	    Simp.draw_prepared_text(g_font, xx restartPos.x - (text_width / 2), xx restartPos.y, color);


	    color = Vector4.{1, 1, 1, 1.0};
	    quitPos := screenCenter;
	    quitPos.y += VEC3_DOWN.y * (height * 0.1);
	    quitPos.x += VEC3_RIGHT.x * (width * 0.1);
	    
	    disToQuit := magnitude(quitPos - g_mousePosition);
	    if (disToQuit <= xx text_width) {
	    	color = PARRY_FX_COLOR;
	    	if (g_inputStateThisFrame & .MousePressedLeft) {
	    		// Restart the game
	    		g_shouldQuitGame = true;
	    	}
	    }
	    text_width = Simp.prepare_text(g_font, "[Quit]");

	    Simp.draw_prepared_text(g_font, xx quitPos.x - (text_width / 2), xx quitPos.y, color);
    	return;
    }

    if (g_isPaused) {
	    text_width = Simp.prepare_text(g_font, "GAME PAUSED!");
	    Simp.draw_prepared_text(g_font, xx (width / 2) - (text_width / 2), xx (height / 2), color);

	    color = Vector4.{1, 1, 1, 1.0};
	    text_width = Simp.prepare_text(g_font, "Resume");
	    resumePos := Vector2.{(width * 0.5), ((height * 0.5) * 0.8)};

	    disToResume := magnitude(resumePos - g_mousePosition);
	    if (disToResume <= 50) {
	    	color = PARRY_FX_COLOR;
	    	if (g_inputStateThisFrame & .MousePressedLeft) {
	    		// Restart the game
	    		g_isPaused = false;
	    	}
	    }

	    Simp.draw_prepared_text(g_font, xx (resumePos.x - (text_width * 0.5)), xx resumePos.y, color);
	    color = Vector4.{1, 1, 1, 1.0};
	    text_width = Simp.prepare_text(g_font, "Quit");
	    quitPos := Vector2.{(width * 0.5), ((height * 0.5) * 0.6)};
	    disToQuitPos := magnitude(quitPos - g_mousePosition);
	    if (disToQuitPos <= 50) {
	    	color = PARRY_FX_COLOR;
	    	if (g_inputStateThisFrame & .MousePressedLeft) {
	    		// Restart the game
	    		g_shouldQuitGame = true;
	    	}
	    }
	    Simp.draw_prepared_text(g_font, xx (quitPos.x - (text_width * 0.5)), xx quitPos.y, color);

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
// 	tracy.ZoneScoped();
	if (g_isPaused) return;
	if (g_restoreTexelOffsetAfter > 0) {
		g_restoreTexelOffsetAfter -= delta;
		return;
	}
	g_additionalTexelOffset = DEFAULT_TEXEL_OFFSET;
}

SpawnPointDefaultTravelDir :: (spawnPosition: SpawnPoint, entity: *Entity) -> Vector3 {
	if #complete spawnPosition == {
		case .Top; return VEC3_DOWN;
		case .Bottom; return VEC3_UP;
		case .Left; return VEC3_RIGHT;
		case .Right; return VEC3_LEFT;
	}
}

// This will spawn if some time and probability is met
SpawnEntities :: (delta: float64) {
    if (g_newWaveAnnouncement) return;
    
	g_enemySpawnTimer += delta;
    
    maxOnScreen := min(MAX_ENEMIES_ON_SCREEN + (g_waveNumber - 1) * 2, 30);
    
	if (g_enemiesSpawnedThisWave < g_enemiesToKillThisWave && 
        g_enemyCount < maxOnScreen && 
        g_enemySpawnTimer >= GetCurrentWaveSpawnInterval() && 
        RandChance(1, 2)) {
		spawnPointGuide : SpawnPoint;
		randomPosition := CalculateRandomSpawnPoint(*spawnPointGuide);
		enemy := CreateEnemy(randomPosition);
		enemy.velocity = SpawnPointDefaultTravelDir(spawnPointGuide, *enemy);
		enemy.rotation = -atan2(enemy.velocity.x, enemy.velocity.y);
		AddEntity(enemy);
		g_enemySpawnTimer = 0.0;
        g_enemiesSpawnedThisWave += 1;
	}
}

HandleCooldownTimers :: (entity: *Entity, delta: float) {
// 	tracy.ZoneScoped();
	if (entity.shootCooldownTimer > 0) {
		entity.shootCooldownTimer -= delta;
	}
}

DrawHealthBar :: (entity: *Entity, delta: float) {
// 	tracy.ZoneScoped();
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

    // clampedPos := SpatialGetCellIndex(entity.position);
    // text := tprint("ClampedPos: (%, %)", clampedPos.x, clampedPos.y);
    // Simp.prepare_text(g_font, text);
    // Simp.draw_prepared_text(g_font, xx (entity.position.x), xx (entity.position.y + 3), .{1, 1, 1, 1});

}

DrawChaosModeBar :: (delta: float) {
// 	tracy.ZoneScoped();
	g_chaosPercentagePrev = g_chaosPercentage;
	g_chaosDepleteTimer -= delta;
	if (g_chaosDepleteTimer <= 0 && !g_newWaveAnnouncement) {
		g_chaosPercentage -= delta * CHAOS_DEPLETE_SPEED;
		g_chaosMultiplier -= delta * CHAOS_DEPLETE_SPEED;
	}
	g_chaosPercentage = clamp(g_chaosPercentage, 0, 1);
	g_chaosMultiplier = clamp(g_chaosMultiplier, 1, 100);

	screenCenterPos := Vector2.{width * 0.75, height * 0.9};
	barPos := screenCenterPos;


    barWidth  : float = width * 0.2;
    barHeight : float = 16.0;
    
    lerpedPct := lerp(g_chaosPercentagePrev, g_chaosPercentage, delta);

    // Background (dark red)
    DrawRect(barPos, Vector2.{barWidth, barHeight}, .{0.4, 0.0, 0.0, 1.0});
    // Foregrround immediate
    DrawRect(barPos, Vector2.{barWidth * g_chaosPercentage, barHeight}, .{0.2, 0.2, 1.0, 0.3});
    // Foreground lerped
    DrawRect(barPos, Vector2.{barWidth * lerpedPct, barHeight}, .{0.0, 0.2, 1.0, 0.2});

	multText := tprint("x%", g_chaosMultiplier);
    text_width := Simp.prepare_text(g_font, multText);
    barPos.y -= barHeight * 1.2;
    Simp.draw_prepared_text(g_font, xx barPos.x, xx barPos.y, POWER_UP_COLOR);
}

AddChaos :: (amount: float) {
// 	tracy.ZoneScoped();
	g_chaosPercentage += amount * g_chaosMultiplier;
	g_chaosDepleteTimer = CHAOS_DEPLETE_WAIT_TIME;
}


AddChaosMultiplier :: (multAmount: float) {
// 	tracy.ZoneScoped();
	g_chaosMultiplier += multAmount;
	g_chaosMultiplier = clamp(g_chaosMultiplier, 1, 3);
}

DrawStaminaBar :: (entity: *Entity, delta: float) {
// 	tracy.ZoneScoped();
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
// 	tracy.ZoneScoped();
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

ShootBullet :: (position: Vector3, shootDir: Vector3, color: Vector4, collisionMask: EEntityType, speed: float = DEFAULT_BULLET_SPEED) {
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
	
	AddChaosMultiplier(CHAOS_MULT_PER_BULLET);
	AddEntity(bullet);
}

ShootShard :: (position: Vector3, shootDir: Vector3, damageAllies: bool) {
	collisionMask : EEntityType;
	color: Vector4;
	lifetime : float = 3;
	speed := DEFAULT_BULLET_SPEED * 0.2;

	if (damageAllies) {
		collisionMask = .Enemy;
		color = Vector4.{0, 1, 0, 1};
	}
	else {
		collisionMask = .Player | .Shield;
		color = ENEMY_BULLET_COLOR;
		// lifetime = 1;
		speed = DEFAULT_BULLET_SPEED * 0.8;
	}
	
	bullet := Entity.{
		type = .Bullet,
		position = position,
		speed = speed,
		shape = .Square,
		flags = .HasLifetime,
		shapeSize = DEFAULT_BULLET_SIZE_PX * 1.5,
		color = color,
		damage = DEFAULT_BULLET_DAMAGE,
		velocity = shootDir,
		rotationVelocity = 2,
		initialLifetime = lifetime,
		remainingLifetime = lifetime,
		collisionMask = collisionMask
	};
	
	AddEntity(bullet);
}

EnemyDeathParticleVFX :: (position: Vector3, shootDir: Vector3) {
	bullet := Entity.{
		type = .VFX,
		position = position,
		speed = DEFAULT_BULLET_SPEED * 0.05,
		shape = .Triangle,
		flags = .HasLifetime | .DecreaseSizeOverLifeTime,
		shapeSize = DEFAULT_BULLET_SIZE_PX * 1.5,
		color = Vector4.{0.3, 0.3, 0.3, 1},
		velocity = shootDir,
		rotationVelocity = 3,
		initialLifetime = 1.5,
		remainingLifetime = 1.5,
		collisionMask = .None
	};
	
	AddEntity(bullet);
}

BulletCollisionParticleVFX :: (position: Vector3, shootDir: Vector3) {
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


ConeVFX :: (position: Vector3, direction: Vector3, delta: float, coneAngle: float = 60.0, particleCount: int = 3) {
    halfCone := coneAngle / 2.0;
    step := coneAngle / cast(float)((particleCount * delta) - 1);

    for i : 0.. cast(int)ceil(particleCount * delta) - 1 {
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

DropBomb :: (position: Vector3) {
	// Instantiate a big ass entity
	entity := Entity.{
		position = position,
		shape = .GradientCircle,
		color = Vector4.{0.3, 0.3, 0.3, 1},
		shapeSize = 1.0,
		collisionMask = .Enemy | .Bullet,
		initialLifetime = 1,
		remainingLifetime = 1,
		type = .BombHolder
	};
	
	g_shakeStrength = 2.0;
	g_additionalTexelOffset = 3.0;
	g_restoreTexelOffsetAfter = 1.5 * SLOW_TIME_SCALE;
	
	g_timeScale = SLOW_TIME_SCALE;
	g_restoreTimeScaleAfter = 1.5;
	g_bombHolderId = AddEntity(entity);
	AddChaos(CHAOS_PER_BOMB);
}

EnemyShoot :: (entity: *Entity, delta: float) {
// 	tracy.ZoneScoped();
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
				ShootBullet(entity.position + (VEC3_RIGHT * SHOOT_POS_OFFSET), VEC3_RIGHT, ENEMY_BULLET_COLOR, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
				ShootBullet(entity.position + (VEC3_LEFT * SHOOT_POS_OFFSET), VEC3_LEFT, ENEMY_BULLET_COLOR, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
				ShootBullet(entity.position + (VEC3_UP * SHOOT_POS_OFFSET), VEC3_UP, ENEMY_BULLET_COLOR, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
				ShootBullet(entity.position + (VEC3_DOWN * SHOOT_POS_OFFSET), VEC3_DOWN, ENEMY_BULLET_COLOR, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
			}
			else {
				shootDir := normalize(g_entities[g_playerId].position - entity.position);
				ShootBullet(entity.position, shootDir, ENEMY_BULLET_COLOR, ENEMY_BULLET_COLLISION_MASK, DEFAULT_BULLET_SPEED * 0.4);
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
	shootDir := normalize(ToVec3(g_mousePosition)- entity.position);
	ShootBullet(entity.position, shootDir, PLAYER_BULLET_COLOR, .Enemy | .Bullet, DEFAULT_BULLET_SPEED * 1.5);
	if (entity.flags & .HasSplitBullet) {
		ShootBullet(entity.position + (VEC3_RIGHT * 2), RotateVec2(shootDir, 90), PARRY_FX_COLOR, .Enemy, DEFAULT_BULLET_SPEED * 1.5);
		ShootBullet(entity.position + (VEC3_LEFT * 2), RotateVec2(shootDir, -90), PARRY_FX_COLOR, .Enemy, DEFAULT_BULLET_SPEED * 1.5);
		g_splitBulletsLeft -= 1;
		
		if (g_splitBulletsLeft <= 0) {
			entity.flags &= ~.HasSplitBullet;
		}
	}
	entity.stamina -= STAMINA_PER_BULLET;
	g_staminaUnchangedTimer	= STAMINA_FADE_THRESHOLD_TIME;
}

CalculateReflectionVector :: (direction: Vector3, normal: Vector3) -> Vector3 {
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

GetFirstNeighborEnemy :: (cell: Vector3, except: u64) -> u64 {
	cellIdx := SpatialGetCellIndex(cell);

	for dx : -1 .. 1 {
		for dy : -1.. 1 {
			h : u64 = SpatialHashCell(.{ cast(s32)(cellIdx.x + dx), cast(s32)(cellIdx.y + dy), cast(s32)(cellIdx.z)});
			entitiesAt : *[..]u64 = SpatialGetEntitiesAt(*g_spatialGrid, h);
			if (entitiesAt != null) {
				for neighbor : << entitiesAt {
					if (g_entities[neighbor].type == .Enemy && neighbor != except) return neighbor;
				}
			}
		}
	}
	return 0;
}
	
HandleCollision :: (first: *Entity, second: *Entity) {
// 	tracy.ZoneScoped();
	if (second.type == .BombHolder && first.type == .Enemy) {
		first.health -= 9999;
		g_timeScale = SLOW_TIME_SCALE;
		g_restoreTimeScaleAfter += 0.2;
		OnDamaged(first, second);
	}
	if (second.type == .BombHolder && first.type == .Bullet) {
		RemoveEntity(first);
	}
	if (first.type == .BombHolder && second.type == .Bullet) {
		RemoveEntity(second);
	}

	if (first.type == .Bullet && second.type == .Enemy) {
		second.health -= first.damage;
		// Again, we should probably address entity deletion some day
		second.cacheVelocity = second.velocity;
		second.velocity = first.velocity * 4;
		second.state = .Knockback;
		OnDamaged(second, first);
		RemoveEntity(first);

		if (g_augmentBits & .ChaosChain) {
			neighborEnemyId : u64 = GetFirstNeighborEnemy(second.position, second.id);
			if (neighborEnemyId != 0) {
				dir := normalize(g_entities[neighborEnemyId].position - second.position);
				ShootBullet(second.position, dir, PLAYER_BULLET_COLOR, .Enemy | .Bullet, DEFAULT_BULLET_SPEED * 1.5);
			}
		}
		if (g_augmentBits & .GetEmClose) {
			blackHole : Entity = .{
				position = second.position,
				shape = .GradientCircle,
				shapeSize = DEFAULT_BLACK_HOLE_SIZE_PX
			};
		}

		for i : 0..6 {
			BulletCollisionParticleVFX(first.position, RotateVec2(first.velocity, i * 60.0));
		}
		return;
	}
	if (first.type == .Player && second.type == .Bullet) {
		if (first.flags & .HasShield) {
			BounceOff(first, second, true);
			return;
		}
		
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
		BounceOff(first, second);
	}

	if (first.type == .Pickup && second.type == .Player) {
		if (AddPowerUps(first.flags, second)) {
			// Do some sound effect
		}
		RemoveEntity(first);
	}
}

BounceOff :: (first: *Entity, second: *Entity, keepFirstStatic: bool = false) {
// 	tracy.ZoneScoped();
	// Calculate the normal of the collision
	diff := second.position - first.position;

    overlapX := (first.shapeSize + second.shapeSize) - abs(diff.x);
    overlapY := (first.shapeSize+ second.shapeSize) - abs(diff.y);

    normal : Vector3;
    if overlapX < overlapY {
    	normal = Vector3.{sign(diff.x), 0, 0};
    }
    else {
    	normal = Vector3.{0, sign(diff.y), 0};
    }


	if (!keepFirstStatic) {
		reflectA := CalculateReflectionVector(first.velocity, normal);
		first.velocity = reflectA;
	}
	reflectB := CalculateReflectionVector(second.velocity, normal);
	second.velocity = reflectB;

	AddChaos(CHAOS_PER_BOUNCE);
}

CalcPowerUpsBitmask :: () -> EEntityFlags {
	mask : u16 = 0;
	baseLine: u16 = 1;
	start := EEntityFlags.PowerUpBeginNumber;
	end := EEntityFlags.PowerUpEndNumber;
	for i : start..end {
		mask |= (baseLine << (i - 1));
	}

	return cast(EEntityFlags)mask;
}

AddPowerUps :: (pickupFlags: EEntityFlags, playerEntity: *Entity) -> bool {
	PowerUpsBitmask :: #run CalcPowerUpsBitmask();

	cleanFlags := pickupFlags & PowerUpsBitmask;
	print("Picked up power up with value: %\n", cleanFlags);
	playerEntity.flags |= cleanFlags;
	if (playerEntity.flags & .HasSplitBullet) {
		g_splitBulletsLeft = SPLIT_BULLET_COUNT;
	}
	if (playerEntity.flags & .HasShield) {
		// Create the shield entity (just a visual)
		InstantiateShield();
	}
	return cleanFlags != 0;
}

InstantiateShield :: () {
	shield := Entity.{
		type = .Shield,
		flags = .HasLifetime,
		initialLifetime = 10,
		remainingLifetime = 10,
		shape = .GradientCircle,
		shapeSize = DEFAULT_PLAYER_SIZE_PX * 2.5,
		color = Vector4.{1, 1, 1, 1},
	};

	AddEntity(shield);
}

DropLoot :: (position: Vector3) {
	powerUpSelectN := RandIntInRange(xx EEntityFlags.PowerUpBeginNumber, xx EEntityFlags.PowerUpEndNumber);

	powerUpSelectReal := cast(EEntityFlags)(1 << (powerUpSelectN - 1)); // yields the value of the flags
	
	entity := Entity.{
		color = POWER_UP_COLOR,
		shape = .Square,
		shapeSize = DEFAULT_ENEMY_SIZE_PX,
		position = position,
		velocity = normalize(ToVec3(RandVec2(Vector2.{0,0}, Vector2.{1,1}))),
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
// 	tracy.ZoneScoped();
	// Now we choose the masks we want to collide with
	TOTAL_MASKS : u64 : size_of(EEntityType) * 8;

	for i : 0.. TOTAL_MASKS - 1 {
		layer := cast(s64)(1 << i);
		factor := cast(s64)(cast(bool)((cast(s64)entity.collisionMask) & layer));
		for j : 0 .. (g_collisionCache[i].count * factor) - 1 {
			otherIdx := g_collisionCache[i][j];
			other : *Entity = *(g_entities[otherIdx]);
			isOtherWithinCollisionMask : bool = (other.type & entity.collisionMask) != 0 && (other.collisionMask & entity.type) != 0;
			if (other.id == entity.id || !isOtherWithinCollisionMask) continue;
			
			collidesOnX := entity.position.x >= other.position.x - (other.shapeSize * other.scaleFactor) && entity.position.x <= other.position.x + (other.shapeSize * other.scaleFactor);
			collidesOnY := entity.position.y >= other.position.y - (other.shapeSize * other.scaleFactor) && entity.position.y <= other.position.y + (other.shapeSize * other.scaleFactor);
		
			if (collidesOnX && collidesOnY) {
				HandleCollision(entity, other);
			}
		}
	}
}

DebugEntities :: () {
	if (g_debugMousePtrEntityId == 0) {
		mousePtrGuide := Entity.{
			type = .Debug,
			position = .{g_mousePosition.x, g_mousePosition.y, 0},
			shape = .Circle,
			shapeSize = 20,
			color = Vector4.{0, 0, 0, 1}
		};
		g_debugMousePtrEntityId = AddEntity(mousePtrGuide);
	}
	g_entities[g_debugMousePtrEntityId].position = .{g_mousePosition.x, g_mousePosition.y, 0};
}

approximately_equal :: (a: Vector3, b: Vector3, epsilon: float = 0.0001) -> bool {
    return abs(a.x - b.x) < epsilon && abs(a.y - b.y) < epsilon && abs(a.z - b.z) < epsilon;
}

magnitude :: (v: Vector2) -> float {
    return sqrt(v.x * v.x + v.y * v.y);
}

magnitude :: (v: Vector3) -> float {
    return sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

RotateVec2 :: (vec: Vector3, degrees: float) -> Vector3 {
	length := magnitude(vec);
	newX := vec.x * cos(degrees * DEG_TO_RAD) - vec.y * sin(degrees * DEG_TO_RAD);
	newY := vec.x * sin(degrees * DEG_TO_RAD) - vec.y * cos(degrees * DEG_TO_RAD);
	return Vector3.{newX, newY, vec.z};
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
		AddChaos(CHAOS_PER_PARRY);
		return false;
	}
	entity.cacheColor = entity.color;
	entity.color = Vector4.{1, 0, 0, 1};
	entity.damageAnimTimer = RECOVER_FROM_DMG_TIME_S;
	if (entity.state == .None) {
		entity.state = .Damaged;
	}
	if (entity.health <= 0 && entity.flags & .ExplodeOnDeath && entity.flags & .ShouldFollowPlayer) {
		entity.flags &= ~.ExplodeOnDeath;
	}
	return true;
}


BombUpdate :: (entity: *Entity, delta: float) {
// 	tracy.ZoneScoped();
	if (entity.remainingLifetime <= 0) {
		RemoveEntity(entity);
		return;
	}
	entity.remainingLifetime -= delta;
	// Fade the color's opacity
	lerpingBlend := entity.remainingLifetime / entity.initialLifetime;
	entity.scaleFactor = lerp(BOMB_RADIUS, 1.0, lerpingBlend);
}

OnRecoverFromDamage :: (entity: *Entity) {
	entity.color = Vector4.{1, 1, 1, 1};
}

HandleKnockback :: (entity: *Entity, delta: float) {
	// Lerp the velocity to 0
	KNOCKBACK_RECOVER_SPEED : float : 20.0;
	entity.velocity = lerp(entity.velocity, Vector3.{0, 0, 0}, delta * KNOCKBACK_RECOVER_SPEED);
	if approximately_equal(entity.velocity, Vector3.{0, 0, 0}) {
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
// 	tracy.ZoneScoped();
	PARRY_ANIM_SPEED :: 20.0;
	if (entity.parryAnimTimer > 0) {
		// Rotate the entity
		entity.rotation += delta * PARRY_ANIM_SPEED;
		entity.parryAnimTimer -= delta;
	}
}
	
UpdatePlayer :: (entity: *Entity, delta: float) {
// 	tracy.ZoneScoped();
	entity.velocity = Vector3.{0, 0, 0};

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

	if (g_inputStateThisFrame & .MousePressedLeft) {
		PlayerShoot(entity);
	}
	if (g_inputStateThisFrame & .MousePressedRight && entity.parryAnimTimer <= 0) {
		// Attempt to parry
		entity.parryPressedTime = cast(float)g_currentTime;
		entity.parryAnimTimer = PLAYER_SWEEP_ANIMATION_TIME;
		entity.cacheColor = entity.color;
		entity.state = .Parry;
		entity.color = PARRY_FX_COLOR;
	}

	if (g_inputStateThisFrame & .SpacePressed && entity.flags & .HasBomb) {
		DropBomb(entity.position);
		entity.flags &= ~.HasBomb;
	}
	for event : events_this_frame {

		if event.type != .KEYBOARD || !event.key_pressed {
        	break;
	    }
		if event.key_code == .MOUSE_BUTTON_RIGHT && entity.parryAnimTimer <= 0 {
		}
		
	}
	
	if input_button_states[cast(int) #char "W"] & .DOWN {
    	entity.velocity += Vector3.{0, 1, 0};
	}
	if input_button_states[cast(int) #char "A"] & .DOWN {
    	entity.velocity += Vector3.{-1, 0, 0};
	}
	if input_button_states[cast(int) #char "S"] & .DOWN {
    	entity.velocity += Vector3.{0, -1, 0};
	}
	if input_button_states[cast(int) #char "D"] & .DOWN {
    	entity.velocity += Vector3.{1, 0, 0};
	}

	// We do not follow the mouse on animation
	if (entity.parryAnimTimer > 0) {
		return;
	}
	entity.velocity = normalize(entity.velocity);
	mouseDir := normalize(.{g_mousePosition.x, g_mousePosition.y, 0} - entity.position);
	tmpAngle := atan2(mouseDir.x, mouseDir.y);
	entity.rotation = -tmpAngle;

	if (entity.velocity != Vector3.{0, 0, 0}) {
		// Draw a trail in a cone
		ConeVFX(entity.position - (entity.velocity * 10), entity.velocity, delta);
	}
}

HealthSystem :: (entity: *Entity, delta: float) {
// 	tracy.ZoneScoped();
	if (entity.type != .Enemy && entity.type != .Player) {
		return;
	}

	if (entity.health <= 0) {
		if (entity.type == .Enemy) {
			IncreaseScore(entity.scoreAmount);
            g_enemiesKilledThisWave += 1;

			if (RandChance(1, 10)) {
				DropLoot(entity.position);
			}

			// Normal animation
			if (entity.flags & .ExplodeOnDeath) {
				g_timeScale = SLOW_TIME_SCALE;
				g_restoreTimeScaleAfter = 0.5;
				AddChaosMultiplier(0.25);
				for i : 0..12 {
					ShootShard(entity.position, RotateVec2(entity.velocity, cast(float)i * 30.0), cast(bool)(entity.flags & .DamageAlliesOnExplosion));
				}
			}
			else {
				for i : 0..6 {
					EnemyDeathParticleVFX(entity.position, RotateVec2(entity.velocity, RandFloatInRange(0, 360)));
				}
			}
			AddChaos(CHAOS_PER_KILL);
			g_enemyCount -= 1;
		}
		RemoveEntity(entity);
		return;
	}
}

FadeEntityOverTime :: (entity: *Entity, delta: float64) {
// 	tracy.ZoneScoped();
	if !(entity.flags & .HasLifetime) {
		return;
	}
	if (entity.remainingLifetime <= 0) {
		if (entity.type == .Shield) {
			g_entities[g_playerId].flags &= ~.HasShield;
		}
		RemoveEntity(entity);
	}

	entity.remainingLifetime -= cast(float)delta;
	// Fade the color's opacity
	lerpingBlend := entity.remainingLifetime / entity.initialLifetime;
	entity.color.w = lerp(0.1, 1.0, lerpingBlend);
	// entity.shapeSize = lerp(5, DEFAULT_BULLET_SIZE_PX, lerpingBlend);
}

DecreaseEntitySizeOverTime :: (entity: *Entity, delta: float64) {
// 	tracy.ZoneScoped();
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
// 	tracy.ZoneScoped();
	g_inputStateThisFrame = .None;

	for event : events_this_frame {
		if event.type == .QUIT {
			g_shouldQuitGame = true;
		}

		if event.type != .KEYBOARD || !event.key_pressed {
        	break;
	    }
		
		if (event.key_code == .MOUSE_BUTTON_LEFT) {
			g_inputStateThisFrame |= .MousePressedLeft;
		}
		
		if event.key_code == .MOUSE_BUTTON_RIGHT {
			g_inputStateThisFrame |= .MousePressedRight;
		}
		if event.key_code == .SPACEBAR {
			g_inputStateThisFrame |= .SpacePressed;
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


FollowSystem :: (entity: *Entity) {
// 	tracy.ZoneScoped();
	if !(entity.flags & .ShouldFollowPlayer) return;
	playerPos: Vector3 = g_entities[g_playerId].position;
	rawVec := playerPos - entity.position;
	direction := normalize(rawVec);
	entity.velocity = direction;
	if (entity.type == .Enemy && entity.flags & .ExplodeOnDeath) {
		distanceToPlayer := magnitude(rawVec);
		if (distanceToPlayer <= 200) {
			// Explode
			entity.health -= 999999;
		}
	}
}

UpdateWaveSystem :: (delta: float) {
// 	tracy.ZoneScoped();
    if (g_waveAnnouncementTimer > 0) {
        g_waveAnnouncementTimer -= delta;
        
        if (g_newWaveAnnouncement && g_newWaveCountdownTimer > 0) {
            g_newWaveCountdownTimer -= delta;
            if (g_newWaveCountdownTimer <= 0) {
                g_newWaveAnnouncement = false;
            }
        }
    }
    
    if (!g_newWaveAnnouncement) {
        CheckWaveCompletion();
    }
    
    if (g_isWaveCleared && g_waveAnnouncementTimer <= 0) {
        if (ShouldStartAugmentPick()) {
            InitAugmentPick();
        } else {
            StartNewWave();
        }
    }
}

Update :: () {
// 	tracy.FrameMark();
// 	tracy.ZoneScoped();
    now := seconds_since_init();
    unscaledDelta: float64 = (now - last_time);
    delta : float64 = unscaledDelta * cast(float64)g_timeScale;
    current_dt = cast(float) delta;

    if current_dt > DT_MAX current_dt = DT_MAX;

    last_time = now;

	g_currentTime += delta;
	
	// DebugEntities();


	InputSystem();
	
	UpdateCollisionCache(g_entities);
    UpdateWaveSystem(current_dt);

    if (g_augmentPickActive) {
        UpdateAugmentPick(current_dt);
        DrawUI(current_dt);
        DrawAugmentPick();
        return;
    }

	RestoreTimeScaleSystem(cast(float)unscaledDelta);
	RestoreTexelOffsetSystem(current_dt);


	SpawnEntities(delta);
	SpatialGridDebugDraw(*g_spatialGrid, g_cameraOffset, cast(float)width, cast(float)height);
	for entity : g_entities {
// 		tracy.ZoneScoped("Entity Iteration");
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
		
		if (entity.type == .Player) {
			UpdatePlayer(*entity, current_dt);
		}
		else if (entity.type == .BombHolder) {
			BombUpdate(*entity, current_dt);
		}
		else if (entity.type == .Shield) {
			(*entity).position = g_entities[g_playerId].position;
		}
		
		FollowSystem(*entity);
		CollisionSystem(*entity);
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

CreateEnemy :: (position: Vector3) -> Entity {
// 	tracy.ZoneScoped();
	shape := EShape.Triangle;
	flags := EEntityFlags.None;
	health := DEFAULT_ENEMY_HEALTH * GetCurrentWaveEnemyHealthMult();
	speed := DEFAULT_ENEMY_SPEED * GetCurrentWaveEnemySpeedMult();
    score := DEFAULT_ENEMY_SCORE + (g_waveNumber - 1) * 2;
    
	if (RandChance(1, 7)) {
		// Creates an AOE enemy
		flags |= .CanMultiShoot | .ExplodeOnDeath | .DamageAlliesOnExplosion;
		shape = .Square;
		health *= 2;
	}
	else if (RandChance(1, 5)) {
		// Creates an exploding enemy that follows you and explodes once it's close enough
		flags |= .ExplodeOnDeath | .ShouldFollowPlayer;
		shape = .Star;
		speed *= 2;
	}
	result := Entity.{
		position = position,
		speed = xx speed,
		shape = shape,
		shapeSize = DEFAULT_ENEMY_SIZE_PX,
		color = Vector4.{1, 1, 1, 1},
		health = health,
		originalHealth = health,
		shootCooldownTimer = ENEMY_SHOOT_COOLDOWN_S,
		scoreAmount = score,
		flags = flags,
		type = .Enemy
	};
	g_enemyCount += 1;
	return result;
}

AddEntity :: (entity: Entity) -> u64 {
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
// 	tracy.ZoneScoped();
	Simp.set_render_target(g_sceneTexture);
	Simp.set_shader_for_color(true);
    Simp.clear_render_target(.0, .01, .03, 1);
    
}

DrawFrameEnd :: () {
// 	tracy.ZoneScoped();
	Simp.set_render_target(g_bloomTempPass);

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
    g_shouldQuitGame = false;
    g_timeScale = 1;
    g_additionalTexelOffset = DEFAULT_TEXEL_OFFSET;
    g_waveNumber = 1;
    g_enemiesKilledThisWave = 0;
    g_waveAnnouncementTimer = 0;
    g_enemiesSpawnedThisWave = 0;
    g_isWaveCleared = false;
    g_newWaveAnnouncement = false;
    g_isPaused = false;
    g_score = 0;
    g_shakeTime = 0;
    g_shakeStrength = 0;
    g_cameraOffset = Vector3.{0, 0, 0};
    g_chaosMultiplier = 1;
    g_chaosPercentagePrev = 0;
    g_chaosPercentage = 0;
    g_augmentBits = .None;
    g_augmentPickActive = false;
    SpatialClear(*g_spatialGrid);

    // Initialize our entity storage
	memset(g_entities.data, 0, g_entities.count * size_of(type_of(g_entities.data.*)));
	InitQueue(*g_availableEntities, cast(s32)ENTITY_MAX_COUNT);
    
	for idx : 0..ENTITY_MAX_COUNT - 1 {
		Enqueue(*g_availableEntities, idx);
	}
        
	// Null entity
    AddEntity(.{type = .None});
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
		position = .{width / 2.0, height / 2.0, 0},
	};

	g_playerId = AddEntity(player);
	
    g_waveNumber = 0;
    g_enemiesToKillThisWave = WAVE_BASE_ENEMIES_PER_WAVE;
    g_waveAnnouncementTimer = WAVE_NEW_WAVE_COUNTDOWN + WAVE_CLEAR_DISPLAY_TIME;
    g_newWaveAnnouncement = true;
    g_newWaveCountdownTimer = WAVE_NEW_WAVE_COUNTDOWN;
}

main :: () {
	last_time = seconds_since_init();	
	g_window = create_window(window_name="TotalChaos Remastered", width=width, height=height);	

	InitRenderingPipeline();
	InitResources();
	InitGame();

    while !g_shouldQuitGame {
//     	tracy.ZoneScoped("Main loop");
    	{
//     		tracy.ZoneScoped("TempStorageReset");
			reset_temporary_storage();
	    }
	    {
//     		tracy.ZoneScoped("UpdateWindowEvents");
			update_window_events();	
	    }
	    	
		mouseX, mouseY := get_mouse_pointer_position();	
        Clamp(*mouseY, 0, height);
        Clamp(*mouseX, 0, width);
		g_mousePosition = Vector2.{cast(float) mouseX, height - cast(float)mouseY};
	
		DrawFrameBegin();
        Update();
        DrawFrameEnd();

        {
// 			tracy.ZoneScoped("SoundUpdate");
	        Sound.update();
        }
		{
// 			tracy.ZoneScoped("BufferSwap");
	        Simp.swap_buffers(g_window);
		}
	}

	sound_player_shutdown();
    
}

