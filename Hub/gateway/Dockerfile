FROM python:3.12.4-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the package contents so module imports work
COPY . .

CMD ["python", "-u", "main.py"]