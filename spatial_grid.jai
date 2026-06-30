#import "Hash_Table";

Vector3i :: struct {
    x: s32;
    y: s32;
    z: s32;
}

CELL_SIZE :: 0.9;
INV_CELL_SIZE :: 1 / CELL_SIZE;

SpatialHashGrid :: struct {
	entitiesAtCell: Table(u64, [..]u64);
}

SpatialRegisterEntityAt :: (spatialGrid: SpatialHashGrid, entity: u64, position: Vector3) {
	cellIdx : Vector3i = SpatialGetCellIndex(position);
	hashedCell : u64 = SpatialHashCell(cellIdx);
	foundEntities : *[..]u64 = table_find_pointer(*(spatialGrid.entitiesAtCell), hashedCell);
	if (foundEntities == null) {
		newArr: [..]u64;
		foundEntities = *newArr;
		table_add(*(spatialGrid.entitiesAtCell), hashedCell, newArr);
		print("Count: %\n", spatialGrid.entitiesAtCell.count);
	}

	array_add(foundEntities, entity);
}

SpatialClear :: (spatialGrid: *SpatialHashGrid) {
	for spatialGrid.entitiesAtCell {
        key, value := it_index, it;
		array_reset_keeping_memory(*value);
	}
}

SpatialGetCellIndex :: (position: Vector3) -> Vector3i {
	return .{
		cast(s32)floor(position.x * INV_CELL_SIZE),
		cast(s32)floor(position.y * INV_CELL_SIZE),
		cast(s32)floor(position.z * INV_CELL_SIZE)
	};

}

SpatialHashCell :: (cell: Vector3i) -> u64 {
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

// GetNeighborsClose(const Vector3 &position, const real_t invCellSize) {
// 	Vector3i cell = this->get_cell_of(position);

// 	std::vector<uint64_t> hits;
// 	for (int dx = -1; dx <= 1; ++dx) {
// 		for (int dy = -1; dy <= 1; ++dy) {
// 			for (int dz = -1; dz <= 1; ++dz) {
// 				uint64_t h = hash_cell({ cell.x + dx, cell.y + dy, cell.z + dz });
// 				auto it = m_nodesByCell.find(h);
// 				if (it != m_nodesByCell.end()) {
// 					hits.insert(hits.end(),
// 							it->second.begin(),
// 							it->second.end());
// 				}
// 			}
// 		}
// 	}
// 	return hits;
// }

