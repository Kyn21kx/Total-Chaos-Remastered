#import "Basic";
#import "String";
using Sound :: #import "Sound_Player"(VERBOSE = false);


SingleSoundPlayer :: struct {
	data: Sound_Data;
	stream: *Sound_Stream;
}

MultiSoundPlayer :: struct {
	sounds: [..]SingleSoundPlayer;
	capacity: s32;
	top: s32 = -1;
}

MultiSoundPlayerInit :: (player: *MultiSoundPlayer, soundClipCount: s32) {
	player.capacity = soundClipCount;
	array_resize(*player.sounds, player.capacity);

    devices := get_devices();
    success := sound_player_init(.{});
    assert(success);
}

// NOTE: Doing this one by one is probably a lot slower than first loading all files and then creating all streams
MultiSoundPlayerLoadSoundFile :: (player: *MultiSoundPlayer, fileName: string, category: Sound_Category) -> s32 {
	player.top += 1;
	assert(player.top < player.capacity, "Unable to push more sound files to multi sound player!");
	singleP : *SingleSoundPlayer = *(player.sounds[player.top]);

	singleP.data = load_audio_file(fileName);
	if (!singleP.data.loaded) {
		print("Failed to load audio file at %!", fileName);
		return -1;
	}
	singleP.stream = make_stream(*singleP.data, category);
	
	return player.top;
}

MultiSoundPlayerSetVolume :: (player: *MultiSoundPlayer, clipID: s32, volume: float) {
	singleP : *SingleSoundPlayer = *(player.sounds[clipID]);
	
	singleP.stream.user_volume_scale = volume;
}

MultiSoundPlayerSetRepeating :: (player: *MultiSoundPlayer, clipID: s32, repeating: bool) {
	singleP : *SingleSoundPlayer = *(player.sounds[clipID]);
	set_repeating(singleP.stream, repeating);
}

MultiSoundPlayerPlay :: (player: *MultiSoundPlayer, clipID: s32) {
	singleP : *SingleSoundPlayer = *(player.sounds[clipID]);
	start_playing(singleP.stream);
}

MultiSoundPlayerPause :: (player: *MultiSoundPlayer, clipID: s32, pauseReason: Sound_Stream.UserFlags) {
	singleP : *SingleSoundPlayer = *(player.sounds[clipID]);
	singleP.stream.user_flags |= pauseReason;
	singleP.stream.current_rate = 0;
}

MultiSoundPlayerResume :: (player: *MultiSoundPlayer, clipID: s32, unpauseReason: Sound_Stream.UserFlags) {
	singleP : *SingleSoundPlayer = *(player.sounds[clipID]);

	singleP.stream.current_rate = singleP.stream.desired_rate;
    singleP.stream.user_flags &= ~unpauseReason;
}

MultiSoundPlayerHasFlag :: (player: *MultiSoundPlayer, clipID: s32, flag: Sound_Stream.UserFlags) -> bool {
	singleP : *SingleSoundPlayer = *(player.sounds[clipID]);
	return cast(bool)(singleP.stream.user_flags & flag);
}


