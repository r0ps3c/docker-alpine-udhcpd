FROM alpine
RUN apk add --no-cache busybox-extras
ENTRYPOINT ["/usr/sbin/udhcpd"]
