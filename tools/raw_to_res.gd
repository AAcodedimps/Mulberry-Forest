extends SceneTree
## Turns the raw sounds made by make_audio.py into the .res files in res://audio/.
## Run from the project folder:  python tools/make_audio.py tools/audio_raw   then
##   godot --headless --path . -s tools/raw_to_res.gd
func _init():
	var dir := "res://tools/audio_raw/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "manifest.json"))
	for name in manifest:
		var info: Dictionary = manifest[name]
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = 22050
		w.stereo = false
		w.data = FileAccess.get_file_as_bytes(dir + name + ".raw")
		if info["loop"]:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(info["samples"])
		var err := ResourceSaver.save(w, "res://audio/%s.res" % name, ResourceSaver.FLAG_COMPRESS)
		print(name, " -> ", err)
	quit()
