FROM alpine:latest

RUN apk add --no-cache \
    curl \
    bash \
    python \
    python-dev \
    py-pip

RUN pip install awscli

RUN cd /usr/local/bin && \
    curl -LO  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl

COPY run.sh /run.sh
RUN chmod +x /run.sh

RUN adduser -D ecr-login
USER ecr-login
ENTRYPOINT ["/run.sh"]
