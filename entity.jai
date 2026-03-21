#import "Basic";
#import "Math";

EEntityType :: enum u16 {
	None;
	Debug :: 1;
	Player :: 2;
	Enemy :: 4;
	Bullet :: 8;
	Pickup :: 16;

	CollisionEnabledLayer :: Player | Enemy | Bullet | Pickup;
}

EShape :: enum u16 {
	None;
	Circle;
	Triangle;
}

EEffectState :: enum u16 {
	None;
	Knockback;
}

DEFAULT_COLLISION_MASK : EEntityType : .CollisionEnabledLayer;

// HealthBarData :: struct {
// 	originalHealth: float;
// 	associatedEntity: m
// }

Entity :: struct {
	id: s64 = -1;
	position : Vector2;
	velocity : Vector2;
	cacheVelocity: Vector2;
	rotation: float;
	rotationVelocity: float;

	state: EEffectState;
	speed: float;
	shape : EShape;
	shapeSize : float;
	color: Vector4;
	cacheColor: Vector4;
	damage: float;
	health: float;
	originalHealth: float;
	damageAnimTimer: float;
	remainingLifetime: float;
	initialLifetime: float;
	shootCooldownTimer: float;

	collisionMask: EEntityType = DEFAULT_COLLISION_MASK;

	type : EEntityType;
}
