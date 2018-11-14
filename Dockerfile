FROM alpine:3.5

RUN apk add --no-cache \
    curl \
    bash \
    python \
    python-dev \
    py-pip

RUN pip install awscli

RUN cd /usr/local/bin && \
    curl -LO  https://storage.googleapis.com/kubernetes-release/release/v1.11.2/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl

COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]