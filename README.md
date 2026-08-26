# InariRevolution 🌌

Godot 4.7で開発した、物理ベースの粒子操作パズルゲーム。
壊れたキューブから放出される「クォーク・電子・光子」を、マウスで吸い寄せて回収し、キューブを修復する。

## 🎮 ゲーム説明

### ゲームフロー
1. キューブをクリック → HP減少 → 粒子放出
2. マウスで粒子を吸い寄せ → インベントリーに保管
3. 全粒子を回収 or HPが満タンに → ラウンド完了

### 粒子の種類
- **クォーク (Q)**: 赤色、出現率54.5%。3個揃うと陽子に融合
- **電子 (e⁻)**: 緑色、出現率44.5%。クォークと反発して光子を生成
- **光子 (γ)**: 黄色、出現率1%。特殊粒子、寿命が無限

### メカニクス
- 磁力と反発力による粒子間の物理演算
- グループ化：3個以上が密着すると安定し、寿命が進まない
- 陽子融合：クォーク3個が3秒間密着で陽子に変化（寿命180秒）

## ⚙️ セットアップ

### 必要な環境
- Godot Engine 4.7 以上
- GDScript（ビルトイン）

### インストール
```bash
git clone https://github.com/inari080/InariRevolution
cd InariRevolution
godot project.godot

テスト実行
bash
godot --headless -d res://addons/gut/gut_cmdline.gd
📁 プロジェクト構成
Code
res://
├── main.gd               # メインゲームロジック（粒子物理・UI管理）
├── glowing_cube.gd       # キューブ（HP・破壊・修復）
├── inventory_bar.gd      # インベントリーバー（画面下）
├── magnetic_trap_ui.gd   # 磁気トラップUI（画面右サイドバー）
├── *.gd                  # その他UI・ボタン
├── tests/
│   ├── test_glowing_cube.gd
│   └── test_spawn_elements.gd
└── addons/gut/           # テストフレームワーク
📊 テスト
実装済みテスト:

HP回復・ダメージロジック: 8/8 ✓
粒子出現数計算: 9/9 ✓
合計: 17/17 テスト合格

実行コマンド:

bash
godot --headless -d res://addons/gut/gut_cmdline.gd
🐛 既知の問題
 デバッグ出力（print文）がコードに残存
 陽子専用画像がなく、クォーク画像を流用中
 将来機能: spawn_next_stage() は未実装
 画面外粒子の処理が不完全
🚀 今後の実装予定
コード整理・重複削除
ログシステム導入
UI/ロジック責任分離
物理演算テスト追加
アニメーション調整
📝 ライセンス
MIT License

👤 作者
@inari080
