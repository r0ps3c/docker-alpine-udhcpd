FROM alpine:3.23

RUN \
	apk --no-cache add busybox-extras=1.37.0-r30 && \
	apk upgrade --no-cache && \
	rm -rf /var/cache/apk/* && \
	mkdir -p /var/lib/misc && \
	touch /var/lib/misc/udhcpd.leases

EXPOSE 67/udp

ENTRYPOINT ["/usr/sbin/udhcpd", "-f"]
