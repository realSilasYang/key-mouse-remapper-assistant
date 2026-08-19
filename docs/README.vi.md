<div align="center">
  <img src="../assets/app/key-mouse-remapper-assistant.png" width="112" alt="Biểu trưng Trợ lý ánh xạ lại bàn phím và chuột">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <strong>Tiếng Việt</strong> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>Trợ lý ánh xạ lại bàn phím và chuột</h1>
  <p><strong>Ghi, viết và quản lý ánh xạ bàn phím, chuột phù hợp với quy trình làm việc của bạn</strong></p>

  <p><a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="Bản mới nhất"></a> <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="Lượt tải"></a> <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="Giấy phép"></a> <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 và 11"> <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="AutoHotkey v2"></p>

  <p><a href="#tổng-quan-giao-diện">Giao diện</a> · <a href="#hướng-dẫn-người-dùng">Hướng dẫn</a> · <a href="#4-khối-quy-tắc-và-tập-lệnh-được-quản-lý">Dạng quy tắc</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">Bản phát hành</a> · <a href="./CHANGELOG.en.md">Nhật ký thay đổi</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">Phản hồi</a> · <a href="#hướng-dẫn-nhà-phát-triển">Phát triển</a></p>
</div>

Trợ lý ánh xạ lại bàn phím và chuột là công cụ AutoHotkey v2 dành cho Windows 10／11 x64. Ứng dụng tập hợp ghi đầu vào, quản lý quy tắc, chỉnh sửa mã, tạo và tối ưu bằng AI, kiểm tra cục bộ và trạng thái chạy trong một giao diện. Mỗi bản phát hành chứa các quy tắc dựng sẵn có thể sửa có trong commit phát hành; số khối quy tắc và tập lệnh được quản lý có thể thay đổi.

Quy tắc nằm trong vùng chú thích `@mapping`, có thể đọc và sao lưu. Ứng dụng không cài trình điều khiển hay dịch vụ Windows; ánh xạ chỉ hoạt động khi trợ lý đang chạy. Gói chính thức không chứa địa chỉ AI, khóa API, mô hình, lời nhắc tùy chỉnh hoặc thiết lập cá nhân của máy dựng.

# Tổng quan giao diện

<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview.png" alt="Cửa sổ chính ở chế độ tối" width="100%">
</p>
<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview-light.png" alt="Cửa sổ chính ở chế độ sáng" width="100%">
</p>

Thanh lệnh phía trên thêm, tạm dừng／tiếp tục hàng loạt và xóa quy tắc. Danh sách hiển thị thứ tự, tên, đầu vào nguồn, kết quả, phạm vi và trạng thái; vùng phía dưới ghi trực tiếp nguồn và đích. Danh sách hỗ trợ chọn nhiều, kéo theo nhóm, sắp xếp tạm thời, chú giải nội dung bị cắt, chấm thứ tự màu và nền chọn bo góc ổn định.

## Khả năng chính

- Ghi bàn phím, nút chuột, con lăn và các phím trình duyệt／phương tiện／khởi chạy, có phân biệt phím bổ trợ trái và phải.
- Hỗ trợ nhấn, thả, lặp, nhấn ngắn, giữ, phím đồng thời và điều kiện ứng dụng, cửa sổ, nguồn nhập, phiên.
- Áp dụng nóng khối quy tắc trong tiến trình chính và chạy mã AHK v2 đầy đủ trong tiến trình riêng được quản lý.
- AI tự chọn dạng quy tắc từ một lối vào; kết quả được chuẩn hóa, kiểm tra RuleSpec và kiểm tra cú pháp／khởi động AHK v2.
- Trình soạn thảo có tô cú pháp, tô dòng thay đổi, hoàn tác, làm lại, xóa dòng và cuộn cố định hai dòng.
- Hỗ trợ 13 ngôn ngữ, giao diện theo hệ thống／sáng／tối, chạy quản trị, khởi động cùng đăng nhập và tự cập nhật.

## Phạm vi và giới hạn

- Chỉ hỗ trợ Windows 10／11 x64.
- Không có trình điều khiển nhân nên không xử lý màn hình bảo mật, `Ctrl+Alt+Delete` hoặc phần mềm chặn móc chế độ người dùng.
- Chế độ quản trị mặc định nâng cả khối quy tắc và tập lệnh con để làm việc với ứng dụng đã nâng quyền.
- Vẫn cần xem lại kết quả AI sau khi kiểm tra cục bộ, đặc biệt với tập lệnh thao tác tệp, mạng, tiến trình hoặc hệ thống.

---

**[Hướng dẫn người dùng](#hướng-dẫn-người-dùng)**<br>
[Cài đặt](#1-cài-đặt-và-chạy-lần-đầu) · [Quản lý](#2-thêm-và-quản-lý-ánh-xạ) · [Ghi](#3-ghi-trạng-thái-và-sự-kiện) · [Quy tắc và AI](#4-khối-quy-tắc-tập-lệnh-được-quản-lý-và-ai) · [Cài đặt](#5-cài-đặt) · [Quyền riêng tư](#6-sự-kiện-chẩn-đoán-và-quyền-riêng-tư)

**[Hướng dẫn nhà phát triển](#hướng-dẫn-nhà-phát-triển)**<br>
[Thư mục](#1-thư-mục-và-trách-nhiệm) · [Giới hạn](#2-giới-hạn-tính-đúng) · [Kiểm tra](#3-lệnh-kiểm-tra) · [Phát hành](#4-phát-hành-và-đóng-góp)

# Hỗ trợ dự án

Nếu trợ lý hữu ích cho công việc hằng ngày, bạn có thể hỗ trợ phát triển qua mã QR dưới đây.

<p align="center"><img src="../assets/donate/微信个人收款码.png" width="220" alt="Mã QR WeChat Pay">&nbsp;&nbsp;&nbsp;&nbsp;<img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Mã QR Alipay"></p>

# Hướng dẫn người dùng

## 1. Cài đặt và chạy lần đầu

Tải ZIP di động đầy đủ hoặc ZIP mã nguồn đầy đủ từ [Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases), rồi giải nén toàn bộ vào thư mục có quyền ghi. Bản di động chạy `键鼠重映射小助手.exe` và đã kèm môi trường AutoHotkey v2 x64 cố định. Bản mã nguồn cần cài AutoHotkey v2 x64 rồi chạy `键鼠重映射小助手.ahk`.

Hai ZIP chương trình đều không chứa phông chữ. `fonts.zip` tùy chọn cung cấp các phông Noto dự phòng; hãy cài phông cần dùng vào Windows trước. Trợ lý chỉ liệt kê phông đã cài trong Windows và không tải riêng phông từ ZIP hay thư mục ứng dụng. Phông chữ không bắt buộc để chạy chương trình.

Lần chạy đầu mặc định yêu cầu quyền quản trị. Đóng cửa sổ chính chỉ ẩn xuống khay; dùng mục Thoát ở khay để dừng mọi ánh xạ. Bản di động không phải ứng dụng một tệp, vì vậy hãy giữ cả thư mục khi di chuyển hoặc sao lưu.

## 2. Thêm và quản lý ánh xạ

Thêm mở trình soạn `@mapping` đầy đủ hoặc tạo bằng AI. Nhấp đúp, F2 hoặc menu chuột phải để sửa. Có thể chọn nhiều hàng rồi tạm dừng, tiếp tục, xóa, kéo theo nhóm hoặc đặt chấm thứ tự. Sắp xếp tiêu đề chỉ đổi cách hiển thị. Trong danh sách chính, `Ctrl+Z` hoàn tác và `Ctrl+Shift+Z` làm lại.

## 3. Ghi, trạng thái và sự kiện

Ghi nguồn, ghi đích, nhập tên, tùy chọn phân biệt bổ trợ trái／phải rồi lưu. Trong khi ghi, trợ lý tạm dừng ánh xạ và bật bộ bảo vệ đầu vào riêng; chỉ tiếp tục sau khi mọi phím vật lý đã được thả.

## 4. Khối quy tắc, tập lệnh được quản lý và AI

| Dạng | Phù hợp | Cách chạy |
| --- | --- | --- |
| Khối quy tắc | Một kích hoạt, tổ hợp, nhánh nhấn ngắn／giữ／thả, điều kiện, hành động chuẩn | Phân tích JSON dạng chú thích và áp dụng nóng trong tiến trình chính |
| Tập lệnh được quản lý | Nhiều phím nóng, trạng thái chung, vòng lặp, bộ hẹn giờ, hàm, gọi ngoài, AHK v2 tùy ý | Trợ lý khởi động, tạm dừng, tiếp tục và dừng một tiến trình AutoHotkey riêng |

Tập lệnh được quản lý có thể chạy mã tùy ý nên việc tạo và nhập yêu cầu xác nhận rõ ràng. Không lặp lại chỉ thị do máy chủ chèn, và không dùng `#SingleInstance Force`, `ExitApp` vô điều kiện hoặc `Reload` để phá vòng đời quản lý.

### Tạo và tối ưu bằng AI

Điền địa chỉ API, khóa và mô hình trong Cài đặt rồi thử kết nối. Chỉ có một lối tạo; AI chọn khối quy tắc hoặc tập lệnh dựa trên toàn bộ giới hạn khả năng. Kết quả tạo đi thẳng vào trình soạn thảo; tối ưu hiển thị màn hình xem lại có tô cú pháp và dòng thay đổi.

Quy trình cục bộ bỏ phần bọc, chuẩn hóa trường đã biết, kiểm tra tên phím và ý nghĩa RuleSpec, rồi kiểm tra cú pháp hoặc khởi động AHK v2. Thất bại, từ chối hoặc hủy không ghi đè quy tắc gốc và vẫn giữ yêu cầu trước. Dữ liệu AI chỉ được gửi tới dịch vụ bên thứ ba đã cấu hình khi người dùng chủ động dùng tính năng.

## 5. Cài đặt

Có thể đặt ngôn ngữ, phông chữ, chủ đề, lối tắt, tác vụ khởi động, chế độ quản trị, kiểm tra cập nhật khi chạy, kết nối AI, gói quy tắc và dung lượng sự kiện. Trình xem sự kiện lọc đầu vào, khớp, từ chối điều kiện, hành động, kho và sự kiện hệ thống, đồng thời xuất JSONL. Hãy xem dữ liệu nhạy cảm trước khi chia sẻ.

## 6. Sự kiện, chẩn đoán và quyền riêng tư

Quy tắc nằm trong `键鼠重映射小助手.ahk` ở thư mục chạy; thiết lập AI, hiển thị và khởi động nằm tại `%APPDATA%\KeyMouseRemapperAssistant`. Hãy sao lưu cả hai. Gói chính thức chứa các quy tắc có trong commit phát hành nhưng loại `settings.ini`, `runtime.ini`, `rule-appearance.json`, `window-layout.ini` và mọi tham số AI cục bộ. Dự án không có đo từ xa hoặc tự tải lên.

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# Hướng dẫn nhà phát triển

## 1. Thư mục và trách nhiệm

`app/` phụ trách ứng dụng và cửa sổ; `src/Core/` phụ trách quy tắc, chạy, AI, lịch sử, gói và cập nhật; `src/Input/` phụ trách quan sát và ghi; `src/Localization/` phụ trách 13 ngôn ngữ; `src/Platform/` và `src/UI/` phụ trách tích hợp Windows và giao diện; `tests/` và `tools/` phụ trách kiểm tra và phát hành.

## 2. Giới hạn tính đúng

Khối quy tắc chạy bằng `Hotkey()` trong tiến trình chính; tập lệnh dùng tiến trình riêng có tín hiệu dừng, tạm dừng và sẵn sàng. Bộ bảo vệ tạm thời chỉ hoạt động khi ghi. Việc ghi quy tắc dùng khóa liên tiến trình, so sánh ảnh chụp và thay thế nguyên tử. Màn hình bảo mật và chuỗi chú ý an toàn nằm ngoài phạm vi.

## 3. Lệnh kiểm tra

```powershell
.\tools\bootstrap-toolchain.ps1
.\tests\verify.ps1 -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe -IncludeGui
.\tools\build-release.ps1
```

## 4. Phát hành và đóng góp

Quá trình dựng tạo ZIP di động đầy đủ, ZIP mã nguồn đầy đủ và `fonts.zip` tùy chọn. Hai gói chương trình không chứa phông; gói phông dùng để cài vào Windows. Quá trình dựng từ chối trạng thái cá nhân cùng tham số AI cục bộ và ghi ZIP xác định. Xem [mẫu nhật ký thay đổi](changelog-template.md) và [quy trình phát hành](release-process.md).

### Giấy phép

Dự án dùng [MIT License](../LICENSE). Xem [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) cho thành phần bên thứ ba.
