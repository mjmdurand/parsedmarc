FROM python:3.13-slim

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY parsedmarc.ini /etc/parsedmarc.ini
COPY certs/parsedmarc-combined.pem /etc/parsedmarc/certs/parsedmarc-combined.pem
COPY run.sh /run.sh
RUN chmod +x /run.sh

USER nobody

ENTRYPOINT ["/run.sh"]
