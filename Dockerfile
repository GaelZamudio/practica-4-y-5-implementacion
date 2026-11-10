FROM python:3.13-slim
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY esquema.sql ./
COPY practica-4 ./practica-4
COPY docker/inicializar.py ./docker/inicializar.py
