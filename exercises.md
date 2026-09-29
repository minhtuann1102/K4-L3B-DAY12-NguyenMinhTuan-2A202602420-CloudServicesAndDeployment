# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay placeholder *Câu trả lời của bạn* ở mỗi câu bằng câu
> trả lời của bạn. `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Minh Tuấn  Mã học viên: 2A202602420

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Lúc deploy lên Render em quên điền biến `AGENT_API_KEY`. Nhờ không có giá trị mặc định nên app crash ngay lúc vừa bật, log dashboard báo đỏ cho biết thiếu key và em sửa được luôn.
>
> Nếu để mặc định là `"changeme"`, app vẫn chạy bình thường, health check vẫn báo xanh tưởng đã deploy ngon lành. Nhưng bot quét mạng sẽ dò ra key `"changeme"` lộ trong repo rồi spam API làm cháy tài khoản OpenAI/LLM lúc nào không hay.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật lấy từ container:
>
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T03:16:23.991579+00:00", "user_id": "sv-e2e", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}
> ```
>
> 1. Dùng `jq` hoặc đẩy vào Grafana/ELK để lọc và cộng tổng `cost_usd` theo từng `user_id` xem ai tiêu tốn tiền nhất.
> 2. Bắt trường `level == "error"` để bot tự động bắn cảnh báo qua Slack/Telegram khi có sự cố. Lệnh `print()` chỉ ra text trơn, máy không bóc tách hay lọc tự động được.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73GB (1730 MB) |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Chênh lệch hơn 1.4GB là do bản 1-stage dùng base `python:3.11` đầy đủ, ôm theo cả compiler C/C++, headers, thư viện build hệ thống và cache pip.
>
> Bản multi-stage chỉ cài thư viện ở stage builder, sang runtime dùng `python:3.11-slim` chỉ copy đúng thư mục `/install` sang. Toàn bộ compiler và rác build đều bị vứt lại ở stage đầu nên image nhẹ hơn hẳn 6 lần.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Khi sửa 1 ký tự trong `main.py`: Dockerfile dùng lại cache toàn bộ từ `FROM` tới `RUN pip install` (vì `requirements.txt` không đổi), chỉ chạy lại từ `COPY app ./app` nên build mất chưa tới 2 giây.
>
> Nếu đặt `COPY . .` trước `RUN pip install`: Mỗi lần sửa code là layer `COPY . .` bị mất cache, kéo theo lệnh `pip install` phải tải và cài lại từ đầu, mỗi lần build mất thêm vài phút ngồi chờ rất ức chế.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> 1. App dính lỗ hổng đọc file hoặc thực thi lệnh (RCE).
> 2. Vì chạy root trong container, kẻ tấn công chiếm toàn quyền container, đọc trộm code và biến môi trường.
> 3. Lợi dụng sơ hở cấu hình (như mount docker.sock) hoặc lỗi kernel, hắn escape ra ngoài host và nghiễm nhiên thành **root trên máy host**, chiếm luôn cả server.
>
> Lệnh `USER appuser` cắt đứt ngay từ bước 2: App chỉ chạy với quyền user thường, không can thiệp được file hệ thống và dù có thoát ra ngoài host cũng chỉ là user vô danh, không leo thang lên root được.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Gửi được tối đa **20 request trong 2 giây**.
>
> Cách làm: Bắn 10 request ở giây 59 của phút trước (vừa hết hạn mức), sang giây 00 phút sau bộ đếm reset về 0, bắn tiếp luôn 10 request nữa.
>
> Cơ chế sliding window giải quyết việc này vì nó luôn tính lùi 60s từ thời điểm hiện tại: 10 request ở giây 59 vẫn bị tính vào cửa sổ 60s nên request gửi ở giây 00-01 sẽ bị chặn ngay với mã 429.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> - Rate limit đếm **số request/phút** (chống nghẽn/spam, trả về 429). Cost guard đếm **tổng tiền USD đã tiêu trong tháng** (bảo vệ ngân sách, trả về 402).
> - **Rate limit cho qua, Cost guard chặn:** User gửi 1 request/phút (rất chậm rãi) nhưng mỗi lần nhét prompt dài triệu token; sau vài ngày tiêu hết 10 USD -> Cost guard chặn 402 dù không hề spam.
> - **Cost guard cho qua, Rate limit chặn:** Đầu tháng tài khoản còn nguyên 10 USD, user chạy tool bắn liền 20 request trong 3 giây -> Cost guard thấy còn tiền cho qua, nhưng Rate limit túm lại ngay ở request thứ 11 với mã 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> 1. Redis mất kết nối 30s.
> 2. Cả 3 container check Redis thất bại, `/health` đồng loạt trả 503.
> 3. Orchestrator tưởng cả 3 container bị chết nên kill và restart toàn bộ cùng lúc.
> 4. Container mới bật lên, Redis vẫn chưa online -> 503 -> lại bị restart -> dính crash loop.
> 5. Lúc Redis sống lại thì các container vẫn đang khởi động dở dang, hệ thống sập lâu hơn thực tế.
>
> Tách riêng `/health` (check process sống) và `/ready` (check nối Redis) giúp orchestrator chỉ tạm ngừng đẩy traffic khi Redis chết chứ không restart app bậy bạ.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Em chạy 2 instance (cổng 8000 và 8001) nối chung Redis, kết quả thật:
>
> ```text
> :8000 -> history_length = 0
> :8001 -> history_length = 2
> :8000 -> history_length = 4
> :8001 -> history_length = 6
> ```
>
> `history_length` tăng đều vì mọi instance cùng đọc/ghi một Redis.
>
> Nếu lưu trong `dict` Python của từng process: request vào container nào chỉ thấy lịch sử riêng của container đó, con số sẽ nhảy loạn (ví dụ 0 -> 2 rồi lại về 0 -> 2 khi đổi cổng), bot bị mất trí nhớ và container restart là mất sạch.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> - **Lỗi:** Deploy Render bằng cách build từ source bị chết giữa chừng, log báo `Out of memory: Killed process` (exit code 137).
> - **Nguyên nhân:** Đọc log trên dashboard thấy lệnh `pip install` ngốn quá nhiều RAM, vượt quá mức 512MB của gói Render Free nên bị hệ thống kill.
> - **Cách sửa:** Dùng GitHub Actions CI build sẵn Docker image rồi đẩy lên GHCR. Trên Render chỉ cần chọn "Deploy an existing image from a registry" (`runtime: image`) kéo image về chạy. Không tốn 1MB RAM nào để build, deploy cực nhanh và không bao giờ bị OOM nữa.
