; vi-VN 本地化词条目录。
; 简体中文原文是稳定键；本目录与其它语言保持完全相同的键集合。

class VietnameseStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Nhấn")
        catalog.Set(
            "键鼠重映射小助手",
                "Trợ lý ánh xạ lại bàn phím và chuột")
        catalog.Set(
            "新增",
                "Thêm")
        catalog.Set(
            "删除",
                "Xóa")
        catalog.Set(
            "暂停",
                "Tạm dừng")
        catalog.Set(
            "恢复",
                "Tiếp tục")
        catalog.Set("反转状态", "Đảo trạng thái")
        catalog.Set(
            "序号",
                "STT")
        catalog.Set(
            "来源按键",
                "Khóa nguồn")
        catalog.Set(
            "映射结果",
                "Kết quả được ánh xạ")
        catalog.Set(
            "生效范围",
                "Phạm vi")
        catalog.Set(
            "名称",
                "Tên")
        catalog.Set(
            "新建映射",
                "Ánh xạ mới")
        catalog.Set(
            "映射为",
                "Bản đồ tới")
        catalog.Set(
            "点击录制来源按键",
                "Bấm để ghi lại mã nguồn")
        catalog.Set(
            "点击录制目标按键",
                "Bấm để ghi lại các phím mục tiêu")
        catalog.Set(
            "保存映射",
                "Lưu")
        catalog.Set(
            "清空",
                "Xóa")
        catalog.Set(
            "准备就绪",
                "Sẵn sàng")
        catalog.Set(
            "请按下按键 · Esc 取消",
                "Nhấn phím · Esc để hủy")
        catalog.Set(
            "编辑映射代码",
                "Chỉnh sửa mã ánh xạ")
        catalog.Set(
            "新增映射代码",
                "Thêm mã ánh xạ")
        catalog.Set("规则块", "Quy tắc thường")
        catalog.Set("受托管脚本", "Tập lệnh được quản lý")
        catalog.Set(
            "代码修改尚未保存，确定放弃吗？",
                "Mã có những thay đổi chưa được lưu. Vứt bỏ chúng?")
        catalog.Set(
            "放弃修改",
                "Hủy thay đổi")
        catalog.Set(
            "显示主界面",
                "Hiển thị cửa sổ chính")
        catalog.Set(
            "重新加载",
                "Tải lại")
        catalog.Set(
            "事件查看",
                "Sự kiện")
        catalog.Set("事件详情", "Chi tiết sự kiện")
        catalog.Set("事件：{1}", "Sự kiện: {1}")
        catalog.Set("类别：{1}", "Danh mục: {1}")
        catalog.Set("时间：{1}", "Thời gian: {1}")
        catalog.Set("来源：{1}", "Nguồn: {1}")
        catalog.Set("结果：{1}", "Kết quả: {1}")
        catalog.Set("详情：{1}", "Chi tiết: {1}")
        catalog.Set("按键名称：{1}", "Tên phím: {1}")
        catalog.Set("原始观察", "Quan sát đầu vào thô")
        catalog.Set("退出观察", "Dừng quan sát")
        catalog.Set("原始观察中", "Đang quan sát đầu vào thô")
        catalog.Set("原始观察切换失败：{1}",
            "Không thể đổi chế độ quan sát đầu vào thô: {1}")
        catalog.Set(
            "导入规则包",
                "Nhập gói quy tắc")
        catalog.Set(
            "导出规则包",
                "Gói quy tắc xuất")
        catalog.Set(
            "规则包导出失败：{1}",
                "Xuất gói quy tắc không thành công: {1}")
        catalog.Set(
            "已导出 {1} 条规则：{2}",
                "Đã xuất {1} quy tắc: {2}")
        catalog.Set(
            "规则包导入失败：{1}",
                "Nhập gói quy tắc không thành công: {1}")
        catalog.Set(
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Quá trình nhập hoàn tất: {1} đã thêm, {2} đã thay thế, {3} đã đổi tên, {4} đã bỏ qua.")
        catalog.Set("导入规则包预览", "Xem trước nhập gói quy tắc")
        catalog.Set("来源：{1} · 版本：{2}", "Nguồn: {1} · Phiên bản: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} quy tắc; chọn sẵn {2}. Quyền: {3}")
        catalog.Set("模式", "Chế độ")
        catalog.Set("权限", "Quyền")
        catalog.Set("全选", "Chọn tất cả")
        catalog.Set("全部取消", "Bỏ chọn tất cả")
        catalog.Set("导入所选", "Nhập mục đã chọn")
        catalog.Set("无额外权限", "Không có quyền bổ sung")
        catalog.Set("生成键鼠输入", "Tạo đầu vào bàn phím và chuột")
        catalog.Set("控制活动窗口", "Điều khiển cửa sổ đang hoạt động")
        catalog.Set("执行系统控制", "Thực hiện điều khiển hệ thống")
        catalog.Set("请至少选择一条规则。", "Hãy chọn ít nhất một quy tắc.")
        catalog.Set("导入失败，请查看主窗口状态。", "Nhập thất bại. Hãy xem trạng thái cửa sổ chính.")
        catalog.Set(
            "筛选：",
                "Bộ lọc:")
        catalog.Set(
            "全部事件",
                "Tất cả sự kiện")
        catalog.Set(
            "输入事件",
                "đầu vào")
        catalog.Set(
            "规则运行",
                "Thời gian chạy")
        catalog.Set(
            "规则仓储",
                "Kho lưu trữ")
        catalog.Set(
            "系统事件",
                "Hệ thống")
        catalog.Set(
            "暂停刷新",
                "Tạm dừng")
        catalog.Set(
            "恢复刷新",
                "Tiếp tục")
        catalog.Set(
            "导出事件",
                "Xuất sự kiện")
        catalog.Set(
            "时间",
                "thời gian")
        catalog.Set(
            "类别",
                "Danh mục")
        catalog.Set(
            "事件",
                "Sự kiện")
        catalog.Set(
            "来源 / 规则",
                "Nguồn/quy tắc")
        catalog.Set(
            "结果",
                "kết quả")
        catalog.Set(
            "详情",
                "Chi tiết")
        catalog.Set(
            "输入",
                "đầu vào")
        catalog.Set(
            "运行时",
                "Thời gian chạy")
        catalog.Set(
            "仓储",
                "Kho lưu trữ")
        catalog.Set(
            "系统",
                "Hệ thống")
        catalog.Set(
            "界面",
                "giao diện người dùng")
        catalog.Set(
            "已暂停刷新",
                "Đã tạm dừng")
        catalog.Set(
            "实时刷新",
                "Trực tiếp")
        catalog.Set(
            "显示 {1} 条 · 缓冲区 {2}/{3} · 已丢弃 {4} 条 · {5}",
                "Đang hiển thị {1} · bộ đệm {2}/{3} · đã bỏ {4} · {5}")
        catalog.Set(
            "事件导出失败：{1}",
                "Xuất sự kiện không thành công: {1}")
        catalog.Set(
            "事件已导出：{1}",
                "Sự kiện đã xuất: {1}")
        catalog.Set(
            "退出程序",
                "Thoát chương trình")
        catalog.Set(
            "设置",
                "Cài đặt")
        catalog.Set(
            "界面语言：",
                "Ngôn ngữ giao diện:")
        catalog.Set(
            "界面内容字体：",
                "Phông chữ nội dung giao diện:")
        catalog.Set(
            "主题：",
                "Chủ đề:")
        catalog.Set(
            "跟随系统",
                "Theo hệ thống")
        catalog.Set(
            "浅色",
                "Sáng")
        catalog.Set(
            "深色",
                "Tối")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Phông chữ mặc định của ngôn ngữ ({1})")
        catalog.Set(
            "保存",
                "Lưu")
        catalog.Set(
            "取消",
                "Hủy")
        catalog.Set(
            "已暂停",
                "Đã tạm dừng")
        catalog.Set(
            "已恢复脚本中的自定义顺序。",
                "Đã khôi phục thứ tự tập lệnh tùy chỉnh.")
        catalog.Set(
            "升序",
                "tăng dần")
        catalog.Set(
            "降序",
                "giảm dần")
        catalog.Set(
            "已临时按“{1}”{2}排列；不会改写脚本顺序。",
                "Tạm thời được sắp xếp theo {1} ({2}); thứ tự tập lệnh không thay đổi.")
        catalog.Set(
            "无法恢复自定义顺序：{1}",
                "Không thể khôi phục thứ tự tùy chỉnh: {1}")
        catalog.Set(
            "映射顺序没有变化。",
                "Thứ tự ánh xạ không thay đổi.")
        catalog.Set(
            "无法启动按键录制，请重试。",
                "Không thể bắt đầu ghi phím. Hãy thử lại.")
        catalog.Set("无法启动按键录制：{1}", "Không thể bắt đầu ghi phím: {1}")
        catalog.Set(
            "正在录制来源按键…",
                "Ghi lại khóa nguồn...")
        catalog.Set(
            "正在录制目标按键…",
                "Đang ghi lại các phím mục tiêu...")
        catalog.Set(
            "来源",
                "nguồn")
        catalog.Set(
            "目标",
                "mục tiêu")
        catalog.Set(
            "正在录制{1}按键：{2}",
                "Ghi âm {1} phím: {2}")
        catalog.Set(
            "已录制{1}按键：{2}",
                "Đã ghi {1} phím: {2}")
        catalog.Set(
            "已取消按键录制。",
                "Đã hủy ghi phím.")
        catalog.Set(
            "请先完成或取消当前按键录制。",
                "Trước tiên hãy hoàn tất hoặc hủy bản ghi hiện tại.")
        catalog.Set(
            "请先录制来源按键和目标按键。",
                "Ghi lại cả khóa nguồn và khóa đích trước.")
        catalog.Set(
            "已清空新建区域。",
                "Đã xóa khu vực ánh xạ mới.")
        catalog.Set(
            "请先选择要删除的映射。",
                "Chọn ánh xạ để xóa trước tiên.")
        catalog.Set(
            "所选映射缺少名称，无法删除。",
                "Ánh xạ đã chọn không có tên và không thể xóa.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Chọn ánh xạ để tạm dừng hoặc tiếp tục trước.")
        catalog.Set(
            "所选映射缺少名称，无法修改状态。",
                "Ánh xạ đã chọn không có tên và không thể thay đổi trạng thái.")
        catalog.Set(
            "无法打开映射代码：{1}",
                "Không thể mở mã ánh xạ: {1}")
        catalog.Set(
            "无法打开代码编辑器：{1}",
                "Không thể mở trình soạn thảo mã: {1}")
        catalog.Set(
            "映射 · {1} -> {2}{3}",
                "Ánh xạ · {1} -> {2}{3}")
        catalog.Set(
            "全局",
                "Toàn cầu")
        catalog.Set(
            "按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
                "Tên khóa: {1}`nKhóa ảo: {2}_`nMã quét: {3}")
        catalog.Set(
            "不适用",
                "không có")
        catalog.Set(
            "键盘",
                "Bàn phím")
        catalog.Set(
            "鼠标",
                "Chuột")
        catalog.Set(
            "滚轮",
                "Con lăn chuột")
        catalog.Set(
            "多媒体",
                "Phương tiện truyền thông")
        catalog.Set(
            "命名键",
                "Khóa được đặt tên")
        catalog.Set(
            "左侧 Ctrl",
                "Ctrl trái")
        catalog.Set(
            "右侧 Ctrl",
                "Ctrl phải")
        catalog.Set(
            "左侧 Shift",
                "Shift trái")
        catalog.Set(
            "右侧 Shift",
                "Dịch chuyển phải")
        catalog.Set(
            "左侧 Alt",
                "Alt trái")
        catalog.Set(
            "右侧 Alt",
                "Alt phải")
        catalog.Set(
            "左侧 Win",
                "Thắng trái")
        catalog.Set(
            "右侧 Win",
                "Thắng đúng")
        catalog.Set(
            "读取重映射代码区域失败：{1}",
                "Không thể đọc vùng ánh xạ: {1}")
        catalog.Set(
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Không thể sử dụng nút chuột trái chưa sửa đổi làm khóa nguồn.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "Bản đồ không được viết: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；已应用。",
                "Đã ghi vào tập lệnh: {1} -> {2}; đã áp dụng.")
        catalog.Set(
            "映射未删除：{1}",
                "Bản đồ chưa bị xóa: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；已应用。",
                "Đã xóa khỏi tập lệnh: {1} -> {2}; đã áp dụng.")
        catalog.Set(
            "顺序未保存：{1}",
                "Đơn hàng chưa được lưu: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Đã cập nhật thứ tự tập lệnh từ kết quả được kéo.")
        catalog.Set(
            "映射状态未修改：{1}",
                "Trạng thái ánh xạ không thay đổi: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；已应用。",
                "Đã tiếp tục ánh xạ: {1} -> {2}; đã áp dụng.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；已应用。",
                "Đã tạm dừng ánh xạ: {1} -> {2}; đã áp dụng.")
        catalog.Set(
            "映射代码未保存：{1}",
                "Mã ánh xạ chưa được lưu: {1}")
        catalog.Set(
            "映射代码未新增：{1}",
                "Mã ánh xạ chưa được thêm: {1}")
        catalog.Set(
            "未保存：{1}",
                "Chưa được lưu: {1}")
        catalog.Set(
            "已保存映射代码：{1} -> {2}；已应用。",
                "Đã lưu mã ánh xạ: {1} -> {2}; đã áp dụng.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；已应用。",
                "Đã thêm mã ánh xạ: {1} -> {2}; đã áp dụng.")
        catalog.Set("已保存，正在后台应用…", "Đã lưu; đang áp dụng trong nền...")
        catalog.Set("受托管脚本已应用。", "Đã áp dụng tập lệnh được quản lý.")
        catalog.Set("映射代码没有变化。", "Mã ánh xạ không thay đổi.")
        catalog.Set("映射代码已保存，但受托管脚本应用失败：{1}",
            "Đã lưu mã ánh xạ nhưng không thể áp dụng tập lệnh được quản lý: {1}")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Không thể tạo mã ánh xạ trống: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Cài đặt chưa được lưu: {1}")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} ánh xạ đang hoạt động · thứ tự tập lệnh tùy chỉnh")
        catalog.Set("键鼠重映射小助手设置",
            "Cài đặt trợ lý ánh xạ lại bàn phím và chuột")
        catalog.Set("启动",
            "Khởi động")
        catalog.Set("显示",
            "Hiển thị")
        catalog.Set("规则与事件",
            "Quy tắc và sự kiện")
        catalog.Set("关于",
            "Giới thiệu")
        catalog.Set("事件缓冲区容量（条）：",
            "Dung lượng bộ đệm sự kiện:")
        catalog.Set("事件查看自动跟随最新事件",
            "Tự động theo dõi sự kiện mới nhất")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Ghi, xem xét và kiểm soát mọi ánh xạ bàn phím và chuột")
        catalog.Set("当前版本",
            "Phiên bản hiện tại")
        catalog.Set("运行环境",
            "Môi trường chạy")
        catalog.Set("开源地址",
            "Kho mã nguồn mở")
        catalog.Set("“{1}”必须是 {2} 到 {3} 之间的整数。",
            "“{1}” phải là số nguyên từ {2} đến {3}.")
        catalog.Set("事件缓冲区容量",
            "Dung lượng bộ đệm sự kiện")
        catalog.Set("未知版本",
            "Phiên bản không xác định")
        catalog.Set("{1}（EXE 版）",
            "{1} (bản EXE)")
        catalog.Set("{1}（源码版）",
            "{1} (bản mã nguồn)")
        catalog.Set("设置已保存并已应用。",
            "Đã lưu và áp dụng cài đặt.")
        catalog.Set("Esc 取消录制",
            "Esc hủy ghi")
        catalog.Set("{1}（便携版）", "{1} (bản di động)")
        catalog.Set("快揭不开锅了（≥Д≤）",
            "Sắp cạn kinh phí rồi（≥Д≤）")
        catalog.Set("使用说明", "Hướng dẫn sử dụng")
        catalog.Set("提交反馈", "Gửi phản hồi")
        catalog.Set("支持开源项目", "Ủng hộ dự án mã nguồn mở")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Không tìm thấy ảnh mã QR")
        catalog.Set("如果小助手为您节省了配置键鼠映射的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式（≥Д≤）", "Nếu trợ lý đã giúp bạn tiết kiệm thời gian cấu hình ánh xạ bàn phím và chuột, hãy ủng hộ tác giả qua mã QR bên dưới!`nVui lòng chọn cách ủng hộ (≥Д≤)")
        catalog.Set("无法打开反馈页面：{1}", "Không thể mở trang phản hồi: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "Trợ lý ánh xạ lại bàn phím và chuột dùng để ghi, xem lại và quản lý các ánh xạ bàn phím, chuột. Đóng cửa sổ chính chỉ ẩn ứng dụng vào khay hệ thống; các ánh xạ đã bật vẫn tiếp tục hoạt động.")
        catalog.Set("一、快速上手", "1. Bắt đầu nhanh")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写名称后保存。", "• Chọn Thêm trên thanh phía trên để mở trình soạn thảo @mapping với các trường siêu dữ liệu đã được chuẩn bị. Bạn cũng có thể ghi riêng phím nguồn và phím đích bên dưới, nhập tên rồi lưu.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• Khi ghi, tên chuẩn, tên dễ đọc, mã phím ảo và mã quét được hiển thị theo thời gian thực. Ứng dụng phân biệt Ctrl, Shift, Alt, Win bên trái và bên phải, cũng như đầu vào bàn phím, chuột và con lăn.")
        catalog.Set("二、主界面与代码编辑", "2. Cửa sổ chính và chỉnh sửa mã")
        catalog.Set("• 单击选择映射；双击条目、选中后按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Bấm một lần để chọn ánh xạ. Bấm đúp một hàng, nhấn F2 sau khi chọn hoặc dùng menu chuột phải để sửa toàn bộ khối @mapping.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Ánh xạ đã chọn có thể được tạm dừng, tiếp tục hoặc xóa. Kéo hàng để thay đổi thứ tự lâu dài; thứ tự khối mã trong tập lệnh được đồng bộ ngay.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• Sắp xếp bằng tiêu đề giả chỉ là tạm thời. Các trường luân phiên tăng dần, giảm dần và thứ tự tùy chỉnh; cột số thứ tự luân phiên giảm dần và thứ tự tùy chỉnh. Tập lệnh không bị ghi lại.")
        catalog.Set("• 事件查看记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• Trình xem sự kiện ghi đầu vào, quy tắc khớp, điều kiện từ chối, kết quả thực thi, hoạt động kho và sự kiện hệ thống; hỗ trợ lọc, tạm dừng, xóa và xuất JSONL.")
        catalog.Set("四、事件查看与设置", "4. Trình xem sự kiện và cài đặt")
        catalog.Set("五、后台运行与问题排查", "5. Chạy nền và khắc phục sự cố")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• Ứng dụng vẫn ở khay sau khi đóng cửa sổ chính. Từ khay, bạn có thể hiện lại cửa sổ, tải lại thủ công hoặc thoát hoàn toàn; thay đổi quy tắc ánh xạ thường không cần tải lại thủ công.")
        catalog.Set("仅勾选的规则会被导入。", "Chỉ nhập các quy tắc đã chọn.")
        catalog.Set("三、规则与生效范围", "3. Quy tắc và phạm vi áp dụng")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Tất cả quy tắc thuộc một bộ quy tắc toàn cục duy nhất. Phạm vi và điều kiện có thể được chỉnh chính xác trong trình soạn thảo @mapping; khi lưu, các quy tắc đang hoạt động sẽ được chọn lại ngay.")
        catalog.Set("没有可撤销的映射变更。", "Không có thay đổi ánh xạ nào để hoàn tác.")
        catalog.Set("已撤销上一步映射变更。", "Đã hoàn tác thay đổi ánh xạ gần nhất.")
        catalog.Set("撤销映射变更失败：{1}", "Không thể hoàn tác thay đổi ánh xạ: {1}")
        catalog.Set("没有可重做的映射变更。", "Không có thay đổi ánh xạ nào để làm lại.")
        catalog.Set("已重做映射变更。", "Đã làm lại thay đổi ánh xạ.")
        catalog.Set("重做映射变更失败：{1}", "Không thể làm lại thay đổi ánh xạ: {1}")
        catalog.Set("录制结束后无法恢复重映射：{1}", "Không thể tiếp tục ánh xạ lại sau khi ghi: {1}")
        catalog.Set("• 新增、删除、暂停或恢复、代码编辑、拖动排序和规则包导入均可撤销；Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。", "• Có thể hoàn tác thao tác thêm, xóa, tạm dừng hoặc tiếp tục, chỉnh sửa mã, sắp xếp bằng kéo thả và nhập gói quy tắc. Dùng Ctrl+Z để hoàn tác; Ctrl+Shift+Z hoặc Ctrl+Y để làm lại.")
        catalog.Set("开机自动启动（计划任务）", "Tự khởi động khi đăng nhập（tác vụ theo lịch）")
        catalog.Set("检查更新失败：{1}", "Kiểm tra cập nhật thất bại: {1}")
        catalog.Set("启动时显示主窗口", "Hiển thị cửa sổ chính khi khởi động")
        catalog.Set("更新检查正在进行，请稍候。", "Đang kiểm tra cập nhật. Vui lòng chờ.")
        catalog.Set("关闭", "Tắt")
        catalog.Set("将下载并校验源码发行包，保留个人配置后替换源码并自动重启。", "Gói phát hành mã nguồn sẽ được tải xuống và kiểm tra. Cấu hình cá nhân được giữ lại trong khi mã nguồn được thay thế, rồi trợ lý tự khởi động lại.")
        catalog.Set("桌面与开始菜单快捷方式", "Lối tắt trên màn hình nền và menu Bắt đầu")
        catalog.Set("创建", "Tạo")
        catalog.Set("无法检查更新：{1}", "Không thể kiểm tra cập nhật: {1}")
        catalog.Set("提示", "Thông báo")
        catalog.Set("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。", "Phát hiện tác vụ theo lịch trùng tên nhưng tác vụ đó không do chương trình hiện tại tạo. Để tránh xóa nhầm, hãy xử lý nó trong Trình lập lịch tác vụ trước.")
        catalog.Set("立即更新", "Cập nhật ngay")
        catalog.Set("错误", "Lỗi")
        catalog.Set("创建成功！", "Đã tạo!")
        catalog.Set("无法建立单实例运行锁，小助手将退出。", "Không thể tạo khóa chạy một phiên bản duy nhất. Trợ lý sẽ thoát.")
        catalog.Set("重新加载失败，已保留当前实例：{1}", "Tải lại thất bại`; phiên bản hiện tại vẫn được giữ lại: {1}")
        catalog.Set("稍后", "Để sau")
        catalog.Set("切换", "Chuyển đổi")
        catalog.Set("冲突", "Xung đột")
        catalog.Set("将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。", "Kho mã nguồn sẽ được kiểm tra để bảo đảm không có thay đổi chưa commit, sau đó fast-forward đến thẻ phát hành chính thức và tự khởi động lại.")
        catalog.Set("无法开始更新：{1}", "Không thể bắt đầu cập nhật: {1}")
        catalog.Set("正在检查更新…", "Đang kiểm tra bản cập nhật…")
        catalog.Set("检查更新", "Kiểm tra cập nhật")
        catalog.Set("小助手更新", "Cập nhật trợ lý")
        catalog.Set("将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。", "Toàn bộ gói phát hành sẽ được tải xuống và kiểm tra. Sau đó trợ lý sẽ thoát, thay thế tệp chương trình và tự khởi động lại.")
        catalog.Set("创建快捷方式失败：{1}", "Không thể tạo lối tắt: {1}")
        catalog.Set("当前陪伴您的已经是最新版本的小助手啦！", "Trợ lý đang đồng hành cùng bạn đã là phiên bản mới nhất rồi!")
        catalog.Set("确定", "Xác nhận")
        catalog.Set("没有可安装的应用更新", "Không có bản cập nhật ứng dụng có thể cài đặt")
        catalog.Set("更新检查未返回结果", "Kiểm tra cập nhật không trả về kết quả")
        catalog.Set("开启", "Bật")
        catalog.Set("不可用", "Không khả dụng")
        catalog.Set("启动失败", "Khởi động thất bại")
        catalog.Set("启动时检查小助手更新", "Kiểm tra cập nhật trợ lý khi khởi động")
        catalog.Set("以管理员身份运行", "Chạy với quyền quản trị viên")
        catalog.Set("操作计划任务时发生错误：{1}", "Đã xảy ra lỗi khi thao tác với tác vụ theo lịch: {1}")
        catalog.Set("发现新版本 {1}，当前版本为 {2}。`n`n{3}`n`n是否立即更新？", "Đã có phiên bản mới {1}; phiên bản hiện tại là {2}.`n`n{3}`n`nCập nhật ngay?")
        catalog.Set("开机自动启动", "Tự khởi động khi đăng nhập")
        catalog.Set("输入录制不可用：{1}", "Không thể ghi đầu vào: {1}")
        catalog.Set("新脚本未通过 AutoHotkey 启动验证。", "Tập lệnh mới không vượt qua bước xác minh khởi động AutoHotkey.")
        catalog.Set("保存并运行", "Lưu và chạy")
        catalog.Set("导入并运行", "Nhập và chạy")
        catalog.Set("导入自定义 AHK 代码", "Nhập mã AHK tùy chỉnh")
        catalog.Set("继续", "Tiếp tục")
        catalog.Set("切换规则类型", "Chuyển loại quy tắc")
        catalog.Set("切换规则类型会清空当前未保存内容，是否继续？", "Chuyển loại quy tắc sẽ xóa nội dung chưa lưu hiện tại. Tiếp tục?")
        catalog.Set("所选规则包含可读写文件、启动程序、控制窗口和请求管理员权限的自定义 AHK 代码。确认导入并运行吗？", "Các quy tắc đã chọn chứa mã AHK tùy chỉnh có thể đọc và ghi tệp, khởi chạy chương trình, điều khiển cửa sổ và yêu cầu quyền quản trị. Nhập và chạy?")
        catalog.Set("无法创建规则模板：{1}", "Không thể tạo mẫu quy tắc: {1}")
        catalog.Set("运行自定义 AHK 代码", "Chạy mã AHK tùy chỉnh")
        catalog.Set("自定义 AHK 代码可读取文件、启动程序、控制窗口并请求管理员权限。确认运行当前代码吗？", "Mã AHK tùy chỉnh có thể đọc và ghi tệp, khởi chạy chương trình, điều khiển cửa sổ và yêu cầu quyền quản trị. Chạy mã này?")
        catalog.Set("规则未应用：{1}", "Không áp dụng được quy tắc: {1}")
        catalog.Set("• 映射区域以注释形式保存规则块和受托管脚本。规则块在主进程热应用；受托管脚本的自定义 AHK v2 源码在独立受管进程运行，保存、暂停、恢复、删除和退出均由小助手统一管理。", "• Vùng ánh xạ lưu khối quy tắc thông thường và tập lệnh được quản lý dưới dạng chú thích. Khối thông thường được áp dụng trong tiến trình chính. Mã AutoHotkey v2 tùy chỉnh chạy trong tiến trình được quản lý riêng do trợ lý kiểm soát.")
        catalog.Set("区分左右修饰键", "Phân biệt phím bổ trợ trái/phải")
        catalog.Set("帮助", "Trợ giúp")
        catalog.Set("打赏", "Ủng hộ")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Mở Trợ giúp`nChọn hướng dẫn sử dụng, nhật ký chạy hoặc gửi phản hồi")
        catalog.Set("点个 star 吧~", "Hãy thắp sáng một ngôi sao nhỏ~")
        catalog.Set("配置显示、规则包和事件选项", "Cấu hình hiển thị, gói quy tắc và sự kiện")
        catalog.Set("查看版本、运行环境和项目入口", "Xem phiên bản, môi trường chạy và liên kết dự án")
        catalog.Set("找作者对线", "Trao đổi với tác giả")
        catalog.Set("演奏你的和弦！", "Hãy chơi hợp âm của bạn!")
        catalog.Set("• “帮助”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• Trợ giúp cũng mở trang phản hồi của dự án. Khi báo lỗi, hãy nêu phiên bản Windows, các bước tái hiện, mã @mapping liên quan và tệp xuất sự kiện; xóa đường dẫn hoặc thông tin ứng dụng nhạy cảm trước khi đăng công khai.")
        catalog.Set("AI 设置", "AI settings")
        catalog.Set("API 地址：", "Địa chỉ API:")
        catalog.Set("API 密钥：", "Khóa API:")
        catalog.Set("模型名称：", "Tên mô hình:")
        catalog.Set("请求超时（秒）：", "Request timeout (seconds):")
        catalog.Set("请求超时（秒）", "Request timeout (seconds)")
        catalog.Set("提示词：", "Lời nhắc:")
        catalog.Set("生成", "Tạo")
        catalog.Set("优化", "Tối ưu hóa")
        catalog.Set("系统说明", "Chỉ dẫn hệ thống")
        catalog.Set("编辑", "Edit")
        catalog.Set("AI 提示词", "AI prompts")
        catalog.Set("生成提示词不能为空。", "Generation prompt cannot be empty.")
        catalog.Set("优化提示词不能为空。", "Optimization prompt cannot be empty.")
        catalog.Set("恢复默认", "Restore default")
        catalog.Set("系统说明不能为空。", "System instructions cannot be empty.")
        catalog.Set("生成重映射规则", "Generate remapping rule")
        catalog.Set("优化当前规则", "Optimize current rule")
        catalog.Set("AI 生成规则", "AI tạo quy tắc")
        catalog.Set("设置序号圆点", "Đặt chấm số thứ tự")
        catalog.Set("清除圆点颜色", "Xóa màu chấm")
        catalog.Set("雾松绿", "Xanh thông sương")
        catalog.Set("青灰蓝", "Xanh xám")
        catalog.Set("薰衣草紫", "Tím oải hương")
        catalog.Set("烟粉", "Hồng khói")
        catalog.Set("浅琥珀", "Hổ phách nhạt")
        catalog.Set("静谧青", "Xanh ngọc dịu")
        catalog.Set("珍珠灰", "Xám ngọc trai")
        catalog.Set("已更新 {1} 条规则的序号圆点颜色。", "Đã cập nhật màu chấm số cho {1} quy tắc.")
        catalog.Set("序号圆点颜色未保存：{1}", "Không lưu được màu chấm số: {1}")
        catalog.Set("AI 优化规则", "AI tối ưu quy tắc")
        catalog.Set("请输入规则目的。", "Hãy nhập mục đích của quy tắc.")
        catalog.Set("说点什么吧，我什么都会做的 T_T", "Cứ nói điều bạn muốn, tôi làm được mọi thứ T_T")
        catalog.Set("我是来帮你的，你要干什么？！", "Tôi ở đây để giúp bạn. Bạn muốn làm gì?!")
        catalog.Set("请先关闭当前代码编辑器，再优化其他映射。", "Đóng trình soạn thảo mã hiện tại trước khi tối ưu một ánh xạ khác.")
        catalog.Set("AI 服务尚未初始化。", "The AI service is not initialized.")
        catalog.Set("无法读取当前映射代码：{1}", "Could not read the current mapping code: {1}")
        catalog.Set("AI 正在生成规则，请稍候...", "AI is generating a rule. Please wait...")
        catalog.Set("AI 正在优化规则，请稍候...", "AI đang tối ưu quy tắc. Vui lòng chờ...")
        catalog.Set("AI 请求失败，请检查 AI 设置和网络连接。", "Yêu cầu AI thất bại. Hãy kiểm tra cài đặt AI và kết nối mạng.")
        catalog.Set("测试连接", "Kiểm tra kết nối")
        catalog.Set("正在测试 AI 连接…", "Đang kiểm tra kết nối AI…")
        catalog.Set("AI 连接测试成功。", "Kiểm tra kết nối AI thành công.")
        catalog.Set("AI 连接测试失败：{1}", "Kiểm tra kết nối AI thất bại: {1}")
        catalog.Set("请填写 API 地址。", "Hãy nhập địa chỉ API.")
        catalog.Set("请填写模型名称。", "Hãy nhập tên mô hình.")
        catalog.Set("请求期间编辑器内容已变化，请重新执行 AI 操作。", "The editor changed during the request. Run the AI operation again.")
        catalog.Set("AI 规则已放入编辑器，请检查后保存。", "The AI rule is in the editor. Review it before saving.")
        catalog.Set("状态", "Trạng thái")
        catalog.Set("启用", "Đã bật")
        catalog.Set("无法读取设置文件，已使用默认设置：{1}", "Không thể đọc cài đặt`; đang dùng giá trị mặc định: {1}")
        catalog.Set("审阅 AI 优化结果", "Xem lại kết quả tối ưu của AI")
        catalog.Set("已保留原内容，AI 结果未应用。", "Nội dung gốc đã được giữ lại. Kết quả AI chưa được áp dụng.")
        catalog.Set("AI 结果无法应用到编辑器，请重试。", "Không thể áp dụng kết quả AI vào trình soạn thảo. Hãy thử lại.")
        catalog.Set("无法打开 AI 结果审阅：{1}", "Không thể mở phần xem lại kết quả AI: {1}")
        catalog.Set("当前 {1} 行，AI 建议 {2} 行；约 {3} 行有变化。", "Hiện tại: {1} dòng`; AI đề xuất: {2} dòng`; khoảng {3} dòng đã thay đổi.")
        catalog.Set("当前内容", "Nội dung hiện tại")
        catalog.Set("AI 建议", "Đề xuất của AI")
        catalog.Set("接受结果", "Chấp nhận kết quả")
        catalog.Set("保留原文", "Giữ bản gốc")
        catalog.Set("AI 返回的规则经过自动修复后仍未通过本地校验：{1}", "Quy tắc AI vẫn không vượt qua xác thực cục bộ sau khi tự động sửa: {1}")
        catalog.Set("AI 规则校验结果不完整。", "Kết quả xác thực quy tắc AI chưa đầy đủ.")
        catalog.Set("AI 正在复核规则的实际行为，请稍候...", "AI đang xem xét hành vi thực tế của quy tắc. Vui lòng đợi...")
        catalog.Set("AI 正在根据本地校验结果修复规则，请稍候...", "AI đang sửa quy tắc theo kết quả xác thực cục bộ. Vui lòng đợi...")
        catalog.Set("本地校验失败：{1}", "Xác thực cục bộ thất bại: {1}")
        catalog.Set("失败发生阶段：{1}", "Giai đoạn thất bại: {1}")
        catalog.Set("必须修复根因并重新满足用户原始目的。", "Hãy sửa nguyên nhân gốc và đáp ứng đầy đủ mục đích ban đầu của người dùng.")
        catalog.Set("规则块能力不足，必须改用受托管脚本完整实现。", "Khối quy tắc thông thường không đủ`; hãy dùng tập lệnh được quản lý để triển khai đầy đủ.")
        catalog.Set("未保存：请先用完整的 AHK v2 脚本替换代码占位文字。", "Chưa lưu: trước tiên hãy thay phần giữ chỗ bằng một tập lệnh AHK v2 hoàn chỉnh.")
        catalog.Set("当前等待时间：{1} 秒", "Current wait time: {1} seconds")
        catalog.Set("界面缩放：", "Tỷ lệ giao diện:")
        catalog.Set("界面缩放已保存，正在重新加载…", "Đã lưu tỷ lệ giao diện. Đang tải lại…")
        return catalog
    }
}
