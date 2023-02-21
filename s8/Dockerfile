FROM python:3.11-slim-bullseye

WORKDIR /usermgmt

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY usermgmt.py .

EXPOSE 5000

CMD ["python", "usermgmt.py"]
