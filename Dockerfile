FROM debian:11-slim
MAINTAINER Niccolo Castelli <n.castelli@bytenite.com>

RUN apt-get update  -y && apt-get -y install certbot -y && apt-get clean all
RUN apt-get -y install python3 curl
RUN mkdir -p /etc/letsencrypt
RUN mkdir -p /var/run/secrets/certificates-updater/

CMD ["/entrypoint.sh"]

COPY secret-patch-template.json /
COPY deployment-patch-template.json /
COPY entrypoint.sh /
