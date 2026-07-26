# Crypto Bubbles Wallpaper

这是一个非官方 macOS 桌面层应用，直接显示 [Crypto Bubbles](https://cryptobubbles.net/zh) 的实时气泡画布，并隐藏官网顶部栏、广告和点击交互。

[下载最新版本](https://github.com/engty/crypto-bubbles-wallpaper/releases/latest) | [English documentation](README.md)

## 安装

1. 在最新 GitHub Release 下载 `CryptoBubblesWallpaper-macos.zip`。
2. 解压后，将 `Crypto Bubbles Wallpaper.app` 拖入“应用程序”文件夹。
3. 打开应用，它会出现在菜单栏，并在窗口下方显示官网气泡画布。

发布包使用 ad-hoc 签名，尚未使用 Apple 开发者证书公证。首次运行时若 macOS 阻止打开，请按住 Control 点击应用，选择“打开”，然后在弹窗中确认一次。

## 数据与行为

- 应用直接在原生 `WKWebView` 中加载 `https://cryptobubbles.net/zh`。
- 官网 Canvas、官网脚本和官网行情请求保持不变；本项目不会模拟、代理、保存或重绘任何价格。
- 顶部栏通过原生裁剪视图移除，不向网页注入会改变布局的 CSS 或 JavaScript。
- 仅将官网 `ads.php` 替换为页面预期的空广告数据结构，不改动行情接口和行情请求。
- 桌面窗口会忽略鼠标事件，点击标的不会弹出详情或交易窗口。
- 菜单栏提供“立即刷新”和“退出壁纸”。

行情刷新频率和聚合逻辑由 Crypto Bubbles 官网决定。因此显示会与官网页面一致，但不代表任一单独交易所的逐笔行情。

## 环境要求

- macOS 13 Ventura 或更高版本
- 可访问 `cryptobubbles.net` 的网络

## 本地构建

```bash
git clone https://github.com/engty/crypto-bubbles-wallpaper.git
cd crypto-bubbles-wallpaper
./script/build_and_run.sh --verify
```

构建产物位于 `dist/Crypto Bubbles Wallpaper.app`。脚本会从 `Assets/AppIcon.svg` 重建 `.icns` 图标，因此本地和 GitHub Release 使用同一份图标资产。

## 自动发布

推送 `v0.1.0` 这类版本标签后，GitHub Actions 会在 macOS Runner 上构建应用、把标签版本写入 App、生成 `CryptoBubblesWallpaper-macos.zip`、计算 SHA-256 并创建 GitHub Release。最终用户不需要安装 Swift 或自行编译。

## 免责声明

本项目独立开发，未获 Crypto Bubbles 认可、支持或授权。Crypto Bubbles 名称、数据和服务归其权利人所有。请在遵守官网条款的前提下使用，本项目不构成任何投资建议。

## 许可证

[MIT](LICENSE)
