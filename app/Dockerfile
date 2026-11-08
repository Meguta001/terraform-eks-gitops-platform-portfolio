
FROM python:3.13-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Create a non-root user
RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin appuser

# Copy application source
COPY --chown=appuser:appuser main.py ./main.py

# Run as non-root
USER appuser

EXPOSE 8080

# Container health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2)" || exit 1

CMD ["python", "main.py"]
