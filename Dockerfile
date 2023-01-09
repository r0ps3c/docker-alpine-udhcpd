FROM alpine
RUN \ 
	apk add --no-cache busybox-extras && \
	rm -rf /var/cache/apk/*

ENTRYPOINT ["/usr/sbin/udhcpd"]
