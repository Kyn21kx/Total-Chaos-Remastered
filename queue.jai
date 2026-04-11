#import "Basic";

Queue :: struct(T: Type) {
	data: [..]T;
	front: s32;
	size: s32;
	capacity: s32;
}
	
InitQueue :: (queue: *Queue($T), size: s32) {
	queue.size = 0;
	queue.capacity = size;
	// The only allocation in the game (hopefully)
	array_resize(*queue.data, size);
}

Enqueue :: (queue: *Queue($T), value: T) {
	// TODO: assert capacity
	rear : s32 = (queue.front + queue.size) % queue.capacity;
	queue.data[rear] = value;
	queue.size += 1;
}


Dequeue :: (queue: *Queue($T)) -> bool, T {
	if (queue.size == 0) {
		def : T = ---;
		return false, def;
	}
	result : T = queue.data[queue.front];
	queue.front = (queue.front + 1) % queue.capacity;
	queue.size -= 1;
	return true, result;
}
