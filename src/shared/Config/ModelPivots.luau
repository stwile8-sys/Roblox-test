--!strict
-- Смещение точки опоры от «низа по центру габарита» для моделей со своей опорой (стады).
-- Пишет tools/models/upload.py — руками не править.
return {
	chestLid = Vector3.new(0.0, 0.0, 3.635),
	beltArc = Vector3.new(0.0, 0.0, 26.969),
} :: { [string]: Vector3 }
