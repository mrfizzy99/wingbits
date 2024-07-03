ARG BUILD_BOARD
ARG BUILD_ARCH

FROM balenalib/"$BUILD_BOARD"-debian-python:bullseye-build-20230530 AS base

EXPOSE 30154

ENV WINGBITS_DEVICE_ID=

ENV RECEIVER_HOST=dump1090-fa
ENV RECEIVER_PORT=30005

ENV WINGBITS_CONFIG_VERSION=0.0.5

ARG PERM_INSTALL="curl gettext-base tini ncurses-bin zlib1g" 

RUN apt update && \
	apt install -y $PERM_INSTALL && \
	apt clean && apt autoclean && apt autoremove && \
	rm -rf /var/lib/apt/lists/*

FROM base AS buildstep

ARG READSB_COMMIT=21353a0d9eeb71f42371e053e0104ee06e21b87c
ARG TEMP_INSTALL="git gcc make libusb-1.0-0-dev ncurses-dev build-essential debhelper libncurses5-dev zlib1g-dev python3-dev libzstd-dev pkg-config"

WORKDIR /tmp

RUN apt update && \
	apt install -y $TEMP_INSTALL

WORKDIR /tmp

RUN git clone --single-branch https://github.com/wiedehopf/readsb.git && \
	cd readsb && \
	git checkout $READSB_COMMIT && \
	make -j3 AIRCRAFT_HASH_BITS=14

FROM base AS release

COPY wingbits_installer.sh /tmp
COPY start.sh /
COPY --from=buildstep /tmp/readsb/readsb /usr/bin/feed-wingbits

WORKDIR /tmp

RUN chmod +x /tmp/wingbits_installer.sh && \
	./wingbits_installer.sh && \
	chmod +x /start.sh && \
	mkdir -p /run/wingbits-feed && \
	mkdir -p /etc/wingbits && \
	echo "$WINGBITS_CONFIG_VERSION" > /etc/wingbits/version && \
	rm -rf /tmp/*

#COPY vector.yaml /etc/vector/vector.yaml
RUN curl -o /etc/vector/vector.yaml https://gitlab.com/wingbits/config/-/raw/$WINGBITS_CONFIG_VERSION/vector.yaml
RUN sed -i 's|DEVICE_ID|WINGBITS_DEVICE_ID|g' /etc/vector/vector.yaml

ENTRYPOINT ["/usr/bin/tini", "--", "/start.sh"]
