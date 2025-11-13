FROM python:3.12.4-slim
WORKDIR /app
COPY requirements.txt /app
RUN pip install -r requirements.txt
COPY src /app
CMD ["python", "main.py"]