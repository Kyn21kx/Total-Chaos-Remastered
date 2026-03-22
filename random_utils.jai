#import "Basic";
#import "Random";

RandFloatInRange :: (min: float, max: float) -> float {
	return min + random_get_zero_to_one() * (max - min);
}


RandIntInRange :: (min: int, max: int) -> int {
	return cast(int)RandFloatInRange(cast(float)min, cast(float)max);
}

RandVec2 :: (min: Vector2, max: Vector2) -> Vector2 {
	return Vector2.{ RandFloatInRange(min.x, max.x), RandFloatInRange(min.y, max.y)};
}


RandChance :: (favorable: int, unfavorable: int) -> bool {
	return RandIntInRange(favorable, unfavorable) == unfavorable - 1;
}
