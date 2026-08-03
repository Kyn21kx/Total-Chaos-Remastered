#import "Basic";
#import "Math";

EEntityType :: enum u16 {
	None;
	Debug :: 1;
	Player :: 2;
	Enemy :: 4;
	Bullet :: 8;
	Pickup :: 16;
	VFX :: 32;
	BombHolder :: 64;
	Shield :: 128;
	BlackHole :: 256;

	CollisionEnabledLayer :: Player | Enemy | Bullet | Pickup | BombHolder | Shield;
}

EShape :: enum u16 {
	None;
	Circle;
	Triangle;
	Square;
	GradientCircle;
	Star;
}

EEffectState :: enum u16 {
	None;
	Parry;
	Damaged;
	Knockback;
}

EEntityFlags :: enum u16 {
	None :: 0;
	ExplodeOnDeath :: 1;
	CanMultiShoot :: 2;
	ShouldFollowPlayer :: 4;

	HasLifetime :: 8;
	// Power ups
	PowerUpBeginNumber :: 5; // Not an enum value, utility for ranges
	HasShield :: 16;
	HasBomb :: 32;
	HasSplitBullet :: 64;
	HasGhostBulletChance :: 128;
	PowerUpEndNumber :: 8; // Not an enum value, utility for ranges (increment by 1 when adding a power up)
	DecreaseSizeOverLifeTime :: 256;
	DamageAlliesOnExplosion :: 512;
	
}

DEFAULT_COLLISION_MASK : EEntityType : .CollisionEnabledLayer;

// HealthBarData :: struct {
// 	originalHealth: float;
// 	associatedEntity: m
// }

Entity :: struct {
	id: u64 = 0;
	position : Vector3;
	velocity : Vector3;
	cacheVelocity: Vector3;
	rotation: float;
	scaleFactor: float;
	rotationVelocity: float;

	state: EEffectState;
	speed: float;
	shape : EShape;
	shapeSize : float;
	scoreAmount: s32;
	color: Vector4;
	cacheColor: Vector4;
	damage: float;
	health: float;
	stamina: float;
	originalHealth: float;
	damageAnimTimer: float;
	remainingLifetime: float;
	initialLifetime: float;
	shootCooldownTimer: float;
	shootAnimTimer: float;
	parryAnimTimer: float; // Anim time doubles as cooldown
	parryPressedTime: float;

	collisionMask: EEntityType = DEFAULT_COLLISION_MASK;

	// Trail particle emission (framerate independent, driven by particleRate per second)
	particleEmit: bool;
	particleRate: float;         // particles emitted per second
	particleAccumulator: float;  // internal accumulator for framerate-independent emission
	particleLifetime: float;
	particleSize: float;
	particleColor: Vector4;

	flags: EEntityFlags;
	type : EEntityType;
}

g_collisionCache: [size_of(EEntityType) * 8][..] u64;

// DeBruijn-like algorithm for a log2(n)
ExtractBitIndex :: (layer: u64) -> u64 {

	TAB64 : [64] u64 : .[
	    63,  0, 58,  1, 59, 47, 53,  2,
	    60, 39, 48, 27, 54, 33, 42,  3,
	    61, 51, 37, 40, 49, 18, 28, 20,
	    55, 30, 34, 11, 43, 14, 22,  4,
	    62, 57, 46, 52, 38, 26, 32, 41,
	    50, 36, 17, 19, 29, 10, 13, 21,
	    56, 45, 25, 31, 35, 16,  9, 12,
	    44, 24, 15,  8, 23,  7,  6,  5
	];

    layer |= layer >> 1;
    layer |= layer >> 2;
    layer |= layer >> 4;
    layer |= layer >> 8;
    layer |= layer >> 16;
    layer |= layer >> 32;

    return TAB64[(cast(u64)((layer - (layer >> 1))*0x07EDD5E59A4E28C2)) >> 58];
}
