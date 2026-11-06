FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements-docker.txt ./requirements-docker.txt
RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir -r requirements-docker.txt \
    && find /usr/local -type d -name __pycache__ -prune -exec rm -rf '{}' + \
    && find /usr/local -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete \
    && rm -rf /root/.cache /tmp/*

COPY config/ ./config/
COPY dataset/ ./dataset/
COPY models/ ./models/
COPY src/ ./src/

CMD ["python", "-m", "src.service.controller_service", "--settings", "config/docker-settings.yaml"]
