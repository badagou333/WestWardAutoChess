extends SceneTree
## 07 source-side imported-texture table. Run from the source project. The final
## PCK is then required to reproduce these exact imported RGBA bytes; the raw PNG
## bytes themselves are separately compared to the 05 candidate by qa_assets.py.
const ART := "res://art/runtime/diamond_duel_v1/"
var output := "/tmp/qa07-duel-20261025/source-imported-assets.json"

func sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ART+"manifest.json"))
	var assets: Array = []
	var failures: Array[String] = []
	if not manifest is Dictionary or manifest.get("frames",[]).size() != 17:
		failures.append("source manifest missing or not seventeen frames")
	else:
		for frame in manifest.frames:
			var path := ART+str(frame.image)
			if not ResourceLoader.exists(path):
				failures.append("missing source frame "+str(frame.id))
				continue
			var texture: Texture2D = load(path)
			if texture == null:
				failures.append("unloadable source frame "+str(frame.id))
				continue
			var image: Image = texture.get_image()
			image.convert(Image.FORMAT_RGBA8)
			var raw := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
			assets.append({"id":str(frame.id),"image":str(frame.image),"size":[int(texture.get_size().x),int(texture.get_size().y)],
				"rgba_sha":sha(image.get_data()),"raw_sha":raw})
	var report := {"scope":"07 source imported texture table","checks":assets.size()+1,"failures":failures,"assets":assets}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	print("QA07_SOURCE_ASSETS frames=",assets.size()," failures=",failures.size()," out=",output)
	quit(1 if failures else 0)
