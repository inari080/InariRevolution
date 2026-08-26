# utils/logger.gd
# Logger - デバッグ出力を一元管理
class_name AppLogger

enum LogLevel { DEBUG, INFO, WARN, ERROR }

var enable_debug: bool = OS.is_debug_build()  # デバッグビルド時のみ有効

func log(level: LogLevel, message: String) -> void:
	if level == LogLevel.DEBUG and not enable_debug:
		return
	
	var prefix = {
		LogLevel.DEBUG: "[DEBUG]",
		LogLevel.INFO: "[INFO]",
		LogLevel.WARN: "[WARN]",
		LogLevel.ERROR: "[ERROR]",
	}[level]
	
	print("%s %s" % [prefix, message])

# 静的メソッド（どこからでも呼び出し可能）
static func debug(msg: String) -> void:
	if OS.is_debug_build():
		print("[DEBUG] %s" % msg)

static func info(msg: String) -> void:
	print("[INFO] %s" % msg)

static func warn(msg: String) -> void:
	print("[WARN] %s" % msg)

static func error(msg: String) -> void:
	print("[ERROR] %s" % msg)
