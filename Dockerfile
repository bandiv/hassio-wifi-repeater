ARG BUILD_FROM
FROM $BUILD_FROM

MAINTAINER Andras Vincze <>

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV LANG C.UTF-8

# Install requirements for add-on
RUN apk update && apk add --no-cache bash jq iw hostapd iptables udhcpd udhcpc macchanger  && rm -rf /var/cache/apk/*
 #networkmanager=1.20.8-r0 net-tools=1.60_git20140218-r2 sudo=1.8.31-r0


COPY hostapd.conf /etc/
COPY udhcpd.conf /etc/
COPY wpa_supplicant.conf /etc/
#COPY interfaces /etc/network/interfaces
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
