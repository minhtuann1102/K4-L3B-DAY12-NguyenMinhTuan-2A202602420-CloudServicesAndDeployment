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

> Khi deploy lên Render, tôi quên set biến `AGENT_API_KEY` trong dashboard.
> Với code hiện tại, service build xong nhưng crash ngay lúc startup với
> `ValidationError: agent_api_key Field required` — log đỏ hiện ngay trên
> dashboard, tôi sửa trong 1 phút. Nếu để mặc định `"changeme"`, service sẽ
> khởi động bình thường, health check xanh, tôi tưởng deploy thành công rồi
> chuyển việc khác; trong lúc đó bot quét Internet gọi `/ask` với key
> `"changeme"` (đoán được vì giá trị nằm trong repo) và tiêu tiền LLM của
> tôi — mãi tới khi xem hóa đơn mới phát hiện.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật từ `docker compose logs agent`:
>
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T03:16:23.991579+00:00", "user_id": "sv-e2e", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}
> ```
>
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
> 1. **Truy vấn theo trường:** gộp `cost_usd` theo `user_id` để tìm "user nào
>    tiêu nhiều tiền nhất hôm nay" — chuỗi print không parse được, JSON thì
>    `jq` lọc là ra ngay.
> 2. **Lọc theo mức độ để cảnh báo:** trường `level` cho phép set alert
>    "tỷ lệ `level=error` trong 5 phút vượt 5% thì báo Slack" — print không
>    phân biệt info với error, log gộp chung một loại, không lọc nổi.

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

> Chênh lệch ~1460MB là **build toolchain và base image đầy đủ** mà bản
> 1-stage mang theo vô ích: `python:3.11` bản full (image alone đã 1.61GB,
> chứa compiler, headers, documentation) thay vì `python:3.11-slim` (~150MB),
> cộng cache pip và toàn bộ dependency nằm cùng layer với source. Bản
> multi-stage chỉ copy thư mục `/install` từ builder sang runtime nên compiler
> và lớp đệm bị vứt lại ở stage bị discard — thứ runtime cần chỉ là thư viện
> thuần Python. Kết quả: 1730MB → 271MB (gấp 6.4 lần).

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Dockerfile của tôi theo thứ tự: `FROM` → `COPY requirements.txt` →
> `RUN pip install` → `COPY --from` → `COPY app` → `COPY utils`. Khi sửa 1
> ký tự trong `main.py`: mọi layer từ `FROM` đến `pip install` vẫn **dùng lại
> từ cache** (hash của `requirements.txt` không đổi), chỉ `COPY app ./app`
> trở đi phải chạy lại — build mất ~1 giây. Nếu đặt `COPY . .` trước
> `RUN pip install`, thì sửa `main.py` làm invalid layer `COPY . .` →
> `pip install` chạy lại toàn bộ → mỗi lần sửa code là tốn vài phút cài lại
> thư viện, và cache gần như vô nghĩa.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: (1) attacker khai thác lỗ hổng trong app — ví dụ đọc file
> tùy ý qua một endpoint; (2) container chạy root nên hắn **đọc được mọi file
> trong container**, gồm source và env; (3) kết hợp một lỗ hổng escape tiếp
> (Docker socket mount sai, kernel vuln...), hắn trở thành **root trên host** —
> máy đó có thể đang chạy container của nhiều service khác; (4) từ root host
> hắn lấy tiếp credential cloud qua metadata service. Lệnh `USER appuser`
> (uid 10001) cắt ngay ở bước (2): quyền đọc bị giới hạn theo user thường,
> và nếu thoát được container thì trên host hắn chỉ là user 10001 thường
> đẳng — không còn cửa bước (3) biến thành root ngay lập tức.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> **20 request trong 2 giây.** Cách đạt: gửi 10 request vào giây 59 của phút
> T (hạn mức phút T vừa dùng hết, vẫn hợp lệ), rồi ngay khi đồng hồ sang phút
> T+1 giây 00 reset bộ đếm, gửi tiếp 10 request trong giây 01. Tổng 20 request
> trong 2 giây mà vẫn "đúng luật" — đó là kẽ hở của đếm theo phút cố định.
> Sliding window bịt kín kẽ hở này: 10 request ở giây 59 vẫn nằm trong cửa sổ
> 60s tính tới giây 01 nên request thứ 11 sẽ bị chặn.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit chặn theo **số lượng request/phút** (429), cost guard chặn theo
> **số tiền đã tiêu trong tháng** (402) — một bên đếm nhịp độ, bên kia đếm
> tiền.
>
> - **Rate limit cho qua, cost guard chặn:** user gửi 5 request/phút (dưới
>   hạn mức 10) nhưng mỗi request prompt ~500k token; chạy đều nửa tháng thì
>   tổng chi phí vượt ngân sách 10 USD → request vẫn "hợp nhịp độ" nhưng cost
>   guard phải chặn bằng 402.
> - **Cost guard cho qua, rate limit chặn:** đầu tháng user chưa tiêu đồng
>   nào (cost guard cho qua) nhưng bấm refresh điên cuồng 100 request trong 1
>   phút → rate limit chặn ở request thứ 11 bằng 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> 1. Redis mất kết nối 30 giây. 2. Endpoint gộp (đang là health check của
> orchestrator) trả 503 cho cả 3 container vì `ping()` thất bại. 3.
> Orchestrator thấy "unhealthy" → **restart cả 3 cùng lúc** (cùng một lý do
> fail). 4. Container mới khởi động, Redis vẫn chết → 503 → restart tiếp →
> **vòng lặp restart**. 5. Khi Redis quay lại, cả 3 đang giữa chu kỳ restart,
> không container nào nhận traffic → sự cố 30 giây của Redis thành sự cố dài
> hơn của toàn hệ thống. Tách `/health` (không kiểm tra gì → orchestrator chỉ
> restart khi process thật sự chết) và `/ready` (kiểm tra Redis → LB ngừng
> đẩy traffic nhưng KHÔNG restart) thì Redis chết 30s chỉ khiến traffic dừng
> 30s, service tự hồi khi Redis quay lại.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Tôi chạy 2 instance (cổng 8000 và 8001, chung Redis) và gọi xen kẽ cùng
> `X-User-Id: sv-scale`, kết quả thật:
>
> ```
> lan 1 (instance :8000) -> history_length=0
> lan 2 (instance :8001) -> history_length=2
> lan 3 (instance :8000) -> history_length=4
> lan 4 (instance :8001) -> history_length=6
> lan 5 (instance :8000) -> history_length=8
> lan 6 (instance :8001) -> history_length=10
> ```
>
> `history_length` tăng đều vì mọi instance cùng đọc/ghi một Redis. Nếu lưu
> trong dict Python từng process, con số sẽ **nhảy loạn và lặp lại**: request
> vào instance A luôn thấy history riêng của A (0, 2, 4...), vào B thấy của B
> (0, 2, 4...) — agent "mất trí nhớ" tùy request rớt vào container nào, và
> reset về 0 mỗi lần container restart.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi:** service deploy xong nhưng crash ngay lúc startup. Log hiển thị:
> `NotImplementedError: TODO (CP4): cài đặt install` trong `app/lifecycle.py`
> rồi `Application startup failed. Exiting.`
>
> **Tìm nguyên nhân:** đọc runtime log (dashboard → Logs) thay vì đoán —
> traceback chỉ thẳng dòng `lifecycle.py`, line 59. Nguyên nhân gốc: hàm
> `lifespan` của FastAPI gọi `lifecycle.install()` lúc khởi động, nhưng tôi
> để đó là TODO nên nó ném exception trước khi server kịp bind cổng — container
> start rồi chết ngay.
>
> **Sửa:** cài `install()` và `request_shutdown()` (nhớ lại handler cũ bằng
> `signal.getsignal` trước khi `signal.signal` ghi đè), rebuild và redeploy —
> service khởi động正常. Bài học: mọi dependency trong startup hook phải xong
> trước khi claim "deploy xong", và luôn đọc log thay vì chỉ nhìn trạng thái
> build.
