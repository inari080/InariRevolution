# utils/particle_visual.gd
# ParticleVisual - 粒子の表示情報を一元管理
class_name ParticleVisual

static func visual_for(type_name: String) -> Dictionary:
	"""粒子の種類から表示用テキスト・色を取得"""
	match type_name:
		"Quark":
			return {"text": "Q", "color": Color(1.0, 0.35, 0.35)}
		"Electron":
			return {"text": "e⁻", "color": Color(0.4, 1.0, 0.5)}
		"Photon":
			return {"text": "γ", "color": Color(1.0, 0.95, 0.4)}
		"Proton":
			return {"text": "p⁺", "color": Color(1.0, 0.75, 0.3)}
		_:
			return {"text": "?", "color": Color(0.8, 0.8, 0.8)}
