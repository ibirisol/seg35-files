FROM python:3.11-alpine

WORKDIR /sysload

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY sysload.py .

EXPOSE 5000

CMD ["python", "sysload.py"]
