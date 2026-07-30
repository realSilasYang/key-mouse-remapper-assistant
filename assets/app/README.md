# 应用图标

`key-mouse-remapper-assistant.svg` 是矢量源文件，`key-mouse-remapper-assistant.png` 是高分辨率 RGBA 源图，
`key-mouse-remapper-assistant.ico` 是应用和发行版 EXE 使用的多分辨率 Windows 图标。构建脚本会把
源图规范化为 1024 px 中间图，再生成 ICO，不会保留额外的 master 文件。
SVG 解码前必须设置透明背景；自动门禁会同时检查 PNG 四角和全部 ICO 帧的 alpha，不能
用仅声明 RGBA 但实际填充白色的图像通过验证。

图形使用两枚键帽与双向箭头表达“把一个输入重新映射到另一个输入”。图标只使用
纯色和粗轮廓，确保缩小到 16 px 时仍保留可辨识的青色、珊瑚色方向关系。

重新生成：

```powershell
./tools/build-icon.ps1
```
