Vector3i :: struct {
    x: s32;
    y: s32;
    z: s32;
}

CELL_SIZE :: 0.5;
INV_CELL_SIZE :: 1 / CELL_SIZE;

SpatialHashGrid :: struct {
	lowerLeft: Vector2;
	upperRight: Vector2;
}

GetCellIndex :: (position: Vector3) -> Vector3i {

	return .{
		cast(s32)floor(position.x * INV_CELL_SIZE),
		cast(s32)floor(position.y * INV_CELL_SIZE),
		cast(s32)floor(position.z * INV_CELL_SIZE)
	};

}

HashCell :: (cell: Vector3i) -> u64 {

	P1 : u32 : 73856093;
	P2 : u32 : 19349663;
	P3 : u32 : 83492791;

	// Reinterpret cast to uint32_t (preserves bit pattern)
	x: u32 = cast(u32)cell.x;
	y: u32 = cast(u32)cell.y;
	z: u32 = cast(u32)cell.z;

	// Combine using prime multiplication and XOR
	return cast(u64)((x * P1) ^ (y * P2) ^ (z * P3));
	
}
