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
            "新增映射",
                "Thêm ánh xạ")
        catalog.Set(
            "删除",
                "Xóa")
        catalog.Set(
            "暂停",
                "Tạm dừng")
        catalog.Set(
            "恢复",
                "Tiếp tục")
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
            "设计目的",
                "Mục đích")
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
        catalog.Set(
            "元数据说明",
                "Tham chiếu siêu dữ liệu")
        catalog.Set(
            "RuleSpec 外壳版本，当前必须为 2。",
                "Phiên bản vỏ RuleSpec; hiện phải là 2.")
        catalog.Set(
            "规则模式，当前必须为 managed。",
                "Chế độ quy tắc; hiện phải là managed.")
        catalog.Set(
            "映射的唯一编号，必须与 RuleSpec 的 id 一致。",
                "ID ánh xạ duy nhất; phải khớp với id của RuleSpec.")
        catalog.Set(
            "结构化 RuleSpec JSON 的开始标记。",
                "Dấu bắt đầu của JSON RuleSpec có cấu trúc.")
        catalog.Set(
            "注释化 JSON；可编辑来源、条件、显示信息和输出动作。",
                "JSON dạng chú thích; chỉnh sửa nguồn, điều kiện, thông tin hiển thị và hành động đầu ra.")
        catalog.Set(
            "结构化 RuleSpec JSON 的结束标记。",
                "Dấu kết thúc của JSON RuleSpec có cấu trúc.")
        catalog.Set(
            "规范化 RuleSpec JSON 的 SHA-256 摘要。",
                "Bản tóm lược SHA-256 của JSON RuleSpec đã chuẩn hóa.")
        catalog.Set(
            "生成区只含说明注释，不包含可执行 AHK。",
                "Vùng được tạo chỉ chứa chú thích giải thích, không có AHK thực thi.")
        catalog.Set(
            "整个映射块只允许注释化 RuleSpec JSON；右侧说明仅供参考，不会保存到代码。",
                "Toàn bộ khối ánh xạ chỉ cho phép JSON RuleSpec dạng chú thích; phần giải thích bên phải chỉ để tham khảo và không được lưu.")
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
            "以管理员身份重新启动",
                "Khởi động lại với tư cách quản trị viên")
        catalog.Set(
            "管理员模式（当前）",
                "Chế độ quản trị viên (hoạt động)")
        catalog.Set(
            "无法以管理员身份重新启动（错误代码 {1}）。",
                "Không thể khởi động lại với tư cách quản trị viên (lỗi {1}).")
        catalog.Set(
            "事件查看器",
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
        catalog.Set("诊断包", "Chẩn đoán")
        catalog.Set("诊断包预览", "Xem trước gói chẩn đoán")
        catalog.Set("导出诊断包", "Xuất gói chẩn đoán")
        catalog.Set("诊断包导出失败：{1}", "Không thể xuất gói chẩn đoán: {1}")
        catalog.Set("诊断包已导出：{1}", "Đã xuất gói chẩn đoán: {1}")
        catalog.Set("将导出 {1} 条事件；已脱敏窗口标题 {2}、路径 {3}、文本/命令 {4}、代码 {5}、变量值 {6} 项。是否继续？",
            "Xuất {1} sự kiện? Đã ẩn {2} tiêu đề cửa sổ, {3} đường dẫn, {4} giá trị văn bản/lệnh, {5} giá trị mã và {6} giá trị biến.")
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
            "规则包导入失败，且回滚失败：{1}",
                "Nhập và khôi phục gói quy tắc không thành công: {1}")
        catalog.Set(
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Quá trình nhập hoàn tất: {1} đã thêm, {2} đã thay thế, {3} đã đổi tên, {4} đã bỏ qua.")
        catalog.Set("变量", "Biến")
        catalog.Set("变量快照", "Ảnh chụp biến")
        catalog.Set("导入规则包预览", "Xem trước nhập gói quy tắc")
        catalog.Set("来源：{1} · 版本：{2}", "Nguồn: {1} · Phiên bản: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} quy tắc; chọn sẵn {2}. Quyền: {3}")
        catalog.Set("规则编号", "ID quy tắc")
        catalog.Set("模式", "Chế độ")
        catalog.Set("权限", "Quyền")
        catalog.Set("全选", "Chọn tất cả")
        catalog.Set("全部取消", "Bỏ chọn tất cả")
        catalog.Set("导入所选", "Nhập mục đã chọn")
        catalog.Set("无额外权限", "Không có quyền bổ sung")
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
            "撤销历史",
                "Lịch sử")
        catalog.Set(
            "系统事件",
                "Hệ thống")
        catalog.Set(
            "界面事件",
                "giao diện người dùng")
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
            "历史",
                "Lịch sử")
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
            "无法打开事件查看器：{1}",
                "Không thể mở Trình xem sự kiện: {1}")
        catalog.Set(
            "退出程序",
                "Thoát chương trình")
        catalog.Set(
            "设置",
                "Cài đặt")
        catalog.Set(
            "界面语言",
                "Ngôn ngữ")
        catalog.Set(
            "主题",
                "chủ đề")
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
            "所选映射缺少代码块编号，无法删除。",
                "Ánh xạ đã chọn không có ID khối và không thể xóa được.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Chọn ánh xạ để tạm dừng hoặc tiếp tục trước.")
        catalog.Set(
            "所选映射缺少代码块编号，无法修改状态。",
                "Ánh xạ đã chọn không có ID khối và không thể thay đổi trạng thái.")
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
            "托管规则未应用：{1}",
                "Các quy tắc được quản lý chưa được áp dụng: {1}")
        catalog.Set(
            "无法检查现有映射：{1}",
                "Không thể kiểm tra các ánh xạ hiện có: {1}")
        catalog.Set(
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Không thể sử dụng nút chuột trái chưa sửa đổi làm khóa nguồn.")
        catalog.Set(
            "该来源按键已被现有映射占用。",
                "Khóa nguồn đó đã được sử dụng bởi một ánh xạ khác.")
        catalog.Set(
            "来源按键与目标按键相同，无需建立映射。",
                "Nguồn và đích giống hệt nhau; không cần ánh xạ.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "Bản đồ không được viết: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；正在自动应用。",
                "Viết theo kịch bản: {1} -> {2}; áp dụng tự động.")
        catalog.Set(
            "删除映射",
                "Xóa ánh xạ")
        catalog.Set(
            "映射未删除：{1}",
                "Bản đồ chưa bị xóa: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；正在自动应用。",
                "Đã xóa khỏi tập lệnh: {1} -> {2}; áp dụng tự động.")
        catalog.Set(
            "调整映射顺序",
                "Sắp xếp lại ánh xạ")
        catalog.Set(
            "顺序未保存：{1}",
                "Đơn hàng chưa được lưu: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Đã cập nhật thứ tự tập lệnh từ kết quả được kéo.")
        catalog.Set(
            "暂停映射",
                "Tạm dừng ánh xạ")
        catalog.Set(
            "恢复映射",
                "Tiếp tục ánh xạ")
        catalog.Set(
            "映射状态未修改：{1}",
                "Trạng thái ánh xạ không thay đổi: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；正在自动应用。",
                "Đã tiếp tục ánh xạ: {1} -> {2}; áp dụng tự động.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；正在自动应用。",
                "Ánh xạ bị tạm dừng: {1} -> {2}; áp dụng tự động.")
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
            "已保存映射代码：{1} -> {2}；正在自动应用。",
                "Mã ánh xạ đã lưu: {1} -> {2}; áp dụng tự động.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；正在自动应用。",
                "Đã thêm mã ánh xạ: {1} -> {2}; áp dụng tự động.")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Không thể tạo mã ánh xạ trống: {1}")
        catalog.Set(
            "无法打开设置：{1}",
                "Không thể mở cài đặt: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Cài đặt chưa được lưu: {1}")
        catalog.Set(
            "界面内容字体",
                "phông chữ giao diện người dùng")
        catalog.Set(
            "撤销失败：{1}",
                "Hoàn tác không thành công: {1}")
        catalog.Set(
            "重做失败：{1}",
                "Làm lại không thành công: {1}")
        catalog.Set(
            "已撤销：{1}",
                "Đã hoàn tác: {1}")
        catalog.Set(
            "已重做：{1}",
                "Đã làm lại: {1}")
        catalog.Set(
            "映射配置",
                "Cấu hình ánh xạ")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} ánh xạ đang hoạt động · thứ tự tập lệnh tùy chỉnh")
        catalog.Set("键鼠重映射小助手设置",
            "Cài đặt trợ lý ánh xạ lại bàn phím và chuột")
        catalog.Set("通用",
            "Chung")
        catalog.Set("关于",
            "Giới thiệu")
        catalog.Set("启动时显示主窗口",
            "Hiện cửa sổ chính khi khởi động")
        catalog.Set("单独按 Esc 时取消录制",
            "Nhấn riêng Esc để hủy ghi")
        catalog.Set("事件缓冲区容量（条）：",
            "Dung lượng bộ đệm sự kiện:")
        catalog.Set("事件查看器自动跟随最新事件",
            "Tự động theo dõi sự kiện mới nhất")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Ghi, xem xét và kiểm soát mọi ánh xạ bàn phím và chuột")
        catalog.Set("当前版本",
            "Phiên bản hiện tại")
        catalog.Set("运行环境",
            "Môi trường chạy")
        catalog.Set("查看最新版本",
            "Xem phiên bản mới nhất")
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
        catalog.Set("设置没有变化。",
            "Không có thay đổi cài đặt.")
        catalog.Set("设置已保存并已应用。",
            "Đã lưu và áp dụng cài đặt.")
        catalog.Set("设置",
            "Cài đặt")
        catalog.Set("Esc 取消录制",
            "Esc hủy ghi")
        catalog.Set("事件自动跟随",
            "Theo dõi sự kiện mới nhất")
        catalog.Set("录制", "Ghi")
        catalog.Set("事件", "Sự kiện")
        catalog.Set("{1}（便携版）", "{1} (bản di động)")
        catalog.Set("帮助信息", "Trợ giúp")
        catalog.Set("捐赠", "Ủng hộ")
        catalog.Set("使用说明", "Hướng dẫn sử dụng")
        catalog.Set("提交反馈", "Gửi phản hồi")
        catalog.Set("支持开源项目", "Ủng hộ dự án mã nguồn mở")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Không tìm thấy ảnh mã QR")
        catalog.Set("如果这个项目为您带来了帮助，欢迎通过下方二维码支持作者！`n键鼠重映射小助手将持续保持开源，项目的长期维护有赖于您的支持和鼓励。", "Nếu dự án này hữu ích với bạn, bạn có thể ủng hộ tác giả qua các mã QR bên dưới.`nTrợ lý ánh xạ lại bàn phím và chuột sẽ tiếp tục là phần mềm mã nguồn mở; sự ủng hộ của bạn giúp duy trì dự án lâu dài.")
        catalog.Set("无法打开帮助信息：{1}", "Không thể mở Trợ giúp: {1}")
        catalog.Set("无法打开使用说明：{1}", "Không thể mở hướng dẫn sử dụng: {1}")
        catalog.Set("无法打开捐赠窗口：{1}", "Không thể mở cửa sổ ủng hộ: {1}")
        catalog.Set("无法打开反馈页面：{1}", "Không thể mở trang phản hồi: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "Trợ lý ánh xạ lại bàn phím và chuột dùng để ghi, xem lại và quản lý các ánh xạ bàn phím, chuột. Đóng cửa sổ chính chỉ ẩn ứng dụng vào khay hệ thống; các ánh xạ đã bật vẫn tiếp tục hoạt động.")
        catalog.Set("一、快速上手", "1. Bắt đầu nhanh")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写设计目的后保存。", "• Chọn Thêm trên thanh phía trên để mở trình soạn thảo @mapping với các trường siêu dữ liệu đã được chuẩn bị. Bạn cũng có thể ghi riêng phím nguồn và phím đích bên dưới, nhập mục đích rồi lưu.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• Khi ghi, tên chuẩn, tên dễ đọc, mã phím ảo và mã quét được hiển thị theo thời gian thực. Ứng dụng phân biệt Ctrl, Shift, Alt, Win bên trái và bên phải, cũng như đầu vào bàn phím, chuột và con lăn.")
        catalog.Set("• 同时按下的任意按键会组成一次录制；所有按键释放后结束。录制期间再次点击录制按钮会取消本次录制，不会把该次点击记为 LButton。", "• Mọi phím được giữ đồng thời tạo thành một lần ghi, kết thúc sau khi tất cả phím được thả. Bấm lại nút ghi sẽ hủy lần ghi thay vì lưu cú bấm đó thành LButton.")
        catalog.Set("二、主界面与代码编辑", "2. Cửa sổ chính và chỉnh sửa mã")
        catalog.Set("• 单击选择映射；双击条目、悬停时按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Bấm một lần để chọn ánh xạ. Bấm đúp một hàng, nhấn F2 khi trỏ chuột lên hàng hoặc dùng menu chuột phải để sửa toàn bộ khối @mapping.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Ánh xạ đã chọn có thể được tạm dừng, tiếp tục hoặc xóa. Kéo hàng để thay đổi thứ tự lâu dài; thứ tự khối mã trong tập lệnh được đồng bộ ngay.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• Sắp xếp bằng tiêu đề giả chỉ là tạm thời. Các trường luân phiên tăng dần, giảm dần và thứ tự tùy chỉnh; cột số thứ tự luân phiên giảm dần và thứ tự tùy chỉnh. Tập lệnh không bị ghi lại.")
        catalog.Set("• 映射区域只保存注释化 RuleSpec v2，是映射的唯一持久来源。GUI 创建或编辑的托管规则会直接热应用；可执行 AHK 代码不会被接受。", "• Vùng ánh xạ chỉ lưu RuleSpec v2 đã được chú thích và là nguồn lưu trữ duy nhất. Quy tắc được quản lý tạo hoặc sửa trong GUI sẽ được áp dụng nóng; mã AHK thực thi sẽ bị từ chối.")
        catalog.Set("四、事件、历史与界面设置", "4. Sự kiện, lịch sử và cài đặt giao diện")
        catalog.Set("• 事件查看器记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• Trình xem sự kiện ghi đầu vào, quy tắc khớp, điều kiện từ chối, kết quả thực thi, hoạt động kho và sự kiện hệ thống; hỗ trợ lọc, tạm dừng, xóa và xuất JSONL.")
        catalog.Set("五、后台运行与问题排查", "5. Chạy nền và khắc phục sự cố")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• Ứng dụng vẫn ở khay sau khi đóng cửa sổ chính. Từ khay, bạn có thể hiện lại cửa sổ, tải lại thủ công hoặc thoát hoàn toàn; thay đổi quy tắc ánh xạ thường không cần tải lại thủ công.")
        catalog.Set("• 映射对管理员程序无效时，请从托盘选择以管理员身份重新启动。遇到规则冲突或按键未按预期执行时，先在事件查看器中核对输入和规则结果。", "• Nếu ánh xạ không tác dụng với ứng dụng chạy quyền quản trị, hãy chọn khởi động lại với quyền quản trị từ khay. Khi có xung đột hoặc phím hoạt động không như mong đợi, trước tiên hãy kiểm tra đầu vào và kết quả quy tắc trong Trình xem sự kiện.")
        catalog.Set("• “帮助信息”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• Trợ giúp cũng mở trang phản hồi của dự án. Khi báo lỗi, hãy nêu phiên bản Windows, các bước tái hiện, mã @mapping liên quan và tệp xuất sự kiện; xóa đường dẫn hoặc thông tin ứng dụng nhạy cảm trước khi đăng công khai.")
        catalog.Set("安全模式：已停用所有映射和输入观察。连续启动失败 {1} 次。", "Chế độ an toàn: đã tắt mọi ánh xạ và quan sát đầu vào sau {1} lần khởi động thất bại liên tiếp.")
        catalog.Set("恢复最后正常配置", "Khôi phục cấu hình tốt gần nhất")
        catalog.Set("没有可恢复的最后正常配置。", "Không có cấu hình tốt gần nhất để khôi phục.")
        catalog.Set("最后正常配置恢复失败：{1}", "Không thể khôi phục cấu hình tốt gần nhất: {1}")
        catalog.Set("最后正常配置已恢复，正在自动应用。", "Đã khôi phục cấu hình tốt gần nhất và đang tự động áp dụng.")
        catalog.Set("仅勾选的规则会被导入。", "Chỉ nhập các quy tắc đã chọn.")
        catalog.Set("三、规则与生效范围", "3. Quy tắc và phạm vi áp dụng")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Tất cả quy tắc thuộc một bộ quy tắc toàn cục duy nhất. Phạm vi và điều kiện có thể được chỉnh chính xác trong trình soạn thảo @mapping; khi lưu, các quy tắc đang hoạt động sẽ được chọn lại ngay.")
        catalog.Set("• Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。映射增删、暂停恢复、拖动排序、代码编辑和设置修改都会进入持久历史。", "• Ctrl+Z để hoàn tác; Ctrl+Shift+Z hoặc Ctrl+Y để làm lại. Việc thêm, xóa, tạm dừng, tiếp tục, sắp xếp, sửa mã và thay đổi cài đặt đều được lưu trong lịch sử lâu dài.")
        return catalog
    }
}
