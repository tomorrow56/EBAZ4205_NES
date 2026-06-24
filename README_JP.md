# EBAZ4205 NES (tarunes移植版)

このプロジェクトは、[tarunes](https://github.com/tomorrow56/tarunes) のNESハードウェア実装を、EBAZ4205 Zynq-7000開発ボードへ移植したものです。

## 機能
- **映像:** TMDSアダプタボード経由でHDMI 480p出力
- **音声:** I2S出力（GPIOピンにマッピング）
- **入力:** アダプタボード上の5つのプッシュボタンをA、B、SELECT、STARTにマッピング
- **ROMロード:** Zynq PSがmicroSDカードから `.nes` ROMをPL BRAMに読み込む

## ハードウェア要件
- EBAZ4205ボード（Zynq XC7Z010搭載）
- EBAZ4205アダプタボード（HDMI、ボタン、LED、microSDスロット付き）
- FAT32フォーマットのmicroSDカード

## ディレクトリ構成
- `rtl/`
  - `tarunes_sv/` : VerylからコンパイルされたSystemVerilogソース
  - `rgb2dvi/` : TMDSエンコーダ VHDL IP
  - `*.v` / `*.sv` : トップレベルラッパーおよびカスタムモジュール
- `vivado/`
  - `create_project.tcl` : Vivadoプロジェクト生成スクリプト
  - `create_bd.tcl` : ブロックデザイン生成スクリプト
  - `constraints/` : XDC制約ファイル
- `software/`
  - `nes_loader/` : Zynq PS向けVitis ベアメタルCアプリケーション

## ビルド手順

### 1. ハードウェア（Vivado）
1. Vivado 2023.2以降を起動する。
2. TclコンソールでプロジェクトのVivadoディレクトリに移動する。
3. プロジェクト生成スクリプトを実行する:
   ```tcl
   source vivado/create_project.tcl
   ```
4. **Generate Bitstream** をクリックする。
5. 完了後、ハードウェアをエクスポートする: **File -> Export -> Export Hardware**（ビットストリームを含める）。

### 2. ソフトウェア（Vitis）
1. Vitis IDEを起動し、ワークスペースを `project/software/workspace` に設定する。
2. エクスポートした `.xsa` ファイルを使って新しいプラットフォームプロジェクトを作成する。
3. BSP（Board Support Package）の設定で `xilffs` ライブラリを有効にする。
4. 新しい空のアプリケーションプロジェクト（Standalone、C言語）を作成する。
5. `project/software/nes_loader/src/main.c` をアプリケーションプロジェクトの `src` フォルダにコピーする。
6. アプリケーションをビルドする。

### 3. SDカードの準備
1. microSDカードをFAT32でフォーマットする。
2. ルートディレクトリに `nes` フォルダを作成する。
3. 有効な `.nes` ROMファイル（Mapper 0 / NROMのみ対応）を `nes` フォルダ内に配置し、`game.nes` という名前にする。
   - パス例: `D:\nes\game.nes`
4. `BOOT.BIN`（Vitis/Bootgenで生成）をSDカードのルートにコピーする。

## ピンアサイン
- **HDMI:** アダプタボードのTMDSピンに接続
- **ボタン:**
  - BTN[0] (T19) -> A
  - BTN[1] (P19) -> B
  - BTN[2] (U20) -> SELECT
  - BTN[3] (U19) -> START
  - BTN[4] (V20) -> 未使用
- **I2S音声:**
  - BCLK -> N17
  - LRCK -> R19
  - DOUT -> P20

## 謝辞
- [tarunes](https://github.com/tomorrow56/tarunes) by tomorrow56
- [EBAZ4205_tutorial](https://github.com/tomorrow56/EBAZ4205_tutorial) by tomorrow56
