ARG ALPINE_VERSION=3.21
FROM alpine:$ALPINE_VERSION

RUN apk update && apk add py3-simplejson

COPY main.py /main.py
COPY realms/ /realms/
