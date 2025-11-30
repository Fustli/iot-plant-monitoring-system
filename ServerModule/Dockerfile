FROM python:3.12.4-slim

WORKDIR /app

# Install system utilities (pg_isready) and keep image small
RUN apt-get update && apt-get install -y --no-install-recommends \
	postgresql-client \
	curl \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy application source
COPY app/ /app

# Wait for Postgres to be ready then run Uvicorn
ENV POSTGRES_HOST=postgres
ENV POSTGRES_PORT=5432
ENV TREFLE_API_KEY=""
# If RUN_SEED_ON_START is set to "true" the container will run the DB seeder
# at startup (useful for dev/test). SEED_RESET can be set to "true" to drop
# and recreate tables before seeding. These are safe defaults for production
# because the defaults disable seeding; configure via container envs or App
# Service Application Settings.
ENV RUN_SEED_ON_START=false
ENV SEED_RESET=false

# Start command:
# 1) wait for Postgres
# 2) optionally run seeder if RUN_SEED_ON_START=true
# 3) start uvicorn
CMD ["sh", "-c", "until pg_isready -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER:-iot_user}; do echo waiting for postgres; sleep 1; done; if [ \"${RUN_SEED_ON_START}\" = \"true\" ]; then echo '[startup] RUN_SEED_ON_START=true -> running seed_db.py'; if [ \"${SEED_RESET}\" = \"true\" ]; then python /app/seed_db.py --reset; else python /app/seed_db.py; fi; fi; exec uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1"]

# Platform/container healthcheck: probe the app health endpoint so orchestrators
# (App Service, Container Instances, etc.) can detect readiness and avoid killing
# the container on failing generic probes. Uses curl which is installed above.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
	CMD curl -f http://localhost:8000/health || exit 1