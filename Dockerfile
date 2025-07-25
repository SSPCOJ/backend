FROM alpine:3.19 AS downloader

WORKDIR /app

RUN apk add --no-cache unzip wget jq curl && \
    LATEST_TAG=$(curl -s https://api.github.com/repos/SSPCOJ/frontend/releases/latest | jq -r '.tag_name') && \
    wget https://github.com/SSPCOJ/frontend/releases/download/${LATEST_TAG}/dist.zip && \
    unzip dist.zip -d dist && \
    rm -f dist.zip

FROM python:3.12-alpine
ARG TARGETARCH
ARG TARGETVARIANT

ENV OJ_ENV=production
WORKDIR /app

COPY ./deploy/requirements.txt /app/deploy/

RUN --mount=type=cache,target=/etc/apk/cache,id=apk-cache-${TARGETARCH}${TARGETVARIANT}-final \
    --mount=type=cache,target=/root/.cache/pip,id=pip-cache-${TARGETARCH}${TARGETVARIANT}-final \
    apk add --no-cache gcc libc-dev python3-dev libpq libpq-dev libjpeg-turbo libjpeg-turbo-dev zlib zlib-dev freetype freetype-dev supervisor openssl nginx curl unzip && \
    pip install -r /app/deploy/requirements.txt && \
    apk del gcc libc-dev python3-dev libpq-dev libjpeg-turbo-dev zlib-dev freetype-dev

COPY ./ /app/
COPY --from=downloader --link /app/dist/ /app/dist/

RUN chmod -R u=rwX,go=rX ./ && chmod +x ./deploy/entrypoint.sh

HEALTHCHECK --interval=5s CMD [ "/usr/local/bin/python3", "/app/deploy/health_check.py" ]
EXPOSE 8000
ENTRYPOINT [ "/app/deploy/entrypoint.sh" ]
