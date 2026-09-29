# ═══════════════════════════════════════════════════════════════════
# CP2 — Multi-stage build production-ready
#
# Stage `builder`: chỉ cài dependency (được phép nặng, xây xong là vứt).
# Stage `runtime`: chỉ copy KẾT QUẢ + source code → image nhỏ, không compiler.
#
# Thứ tự COPY requirements.txt → pip install → COPY code: Docker cache theo
# layer, sửa 1 dòng code KHÔNG phải cài lại thư viện.
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder ──────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# COPY riêng requirements.txt trước — layer cache ổn định
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime ─────────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

# Chỉ copy thư viện đã cài từ builder, không mang theo gì thừa
COPY --from=builder /install /usr/local

# Source code copy SAU cùng để cache được tối đa
COPY app ./app
COPY utils ./utils

# Chạy bằng user thường — container root = ai thoát được khỏi app cũng thành root
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

# Platform (Railway/Render/Cloud Run) tự gán cổng qua $PORT, mặc định 8000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request, os; urllib.request.urlopen('http://127.0.0.1:%s/health' % os.environ.get('PORT', '8000')).read()" || exit 1

# --host 0.0.0.0: bind 127.0.0.1 thì ngoài container không gọi vào được
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
