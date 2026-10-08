FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends cron \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ src/
COPY crontab /etc/cron.d/pipeline
RUN sed -i 's/\r$//' /etc/cron.d/pipeline && chmod 0644 /etc/cron.d/pipeline
CMD ["sh", "-c", "printenv | sed \"s/^\\([^=]*\\)=\\(.*\\)$/export \\1='\\2'/\" > /app/env.sh && cron -f"]