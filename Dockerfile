FROM python:3.11-slim

WORKDIR /app

# Copy dependencies first — Docker layer cache skips pip install if requirements unchanged
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app code
COPY app/ .

EXPOSE 5000

CMD ["python", "app.py"]
