# UI font resources

This directory is the build source for the separate optional font ZIP. It contains
only redistributable Noto fallback fonts. Neither program edition includes these
files. Users must install desired fonts into Windows first; the assistant enumerates
only installed system fonts and never loads fonts privately from the ZIP or its
application directory. Fonts are not required to run the application.

- `NotoSans-Variable.ttf` is Noto Sans 2.015 and covers English, Vietnamese,
  Spanish, French, Portuguese, Russian, German, and Italian.
- `NotoSansCJK.ttc` retains five Regular faces extracted from the official Noto
  Sans CJK 2.004 collection for Simplified Chinese, Hong Kong Traditional Chinese,
  Taiwan Traditional Chinese, Japanese, and Korean. Glyphs and family names are
  unchanged.

Both files use the SIL Open Font License 1.1; `OFL-1.1.txt` contains the complete
license. `metadata.json` records their sources, versions, transformation, and
SHA-256 values. Fonts ship only in `fonts.zip` and are absent from both program
editions.
