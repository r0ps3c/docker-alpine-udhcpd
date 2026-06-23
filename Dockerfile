FROM alpine:3.23

RUN \
	apk --no-cache add busybox-extras && \
	apk upgrade --no-cache && \
	rm -rf /var/cache/apk/* && \
	mkdir -p /var/lib/misc && \
	touch /var/lib/misc/udhcpd.leases

EXPOSE 67/udp

ENTRYPOINT ["/usr/sbin/udhcpd", "-f"]
