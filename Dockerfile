#Set mosquitto and plugin versions.
#Change them for your needs.
ARG MOSQUITTO_VERSION=1.6.12
ARG PLUGIN_VERSION=1.3.0
ARG GO_VERSION=1.15.3

#Use debian:stable-slim as a builder and then copy everything.
FROM debian:stable-slim as builder

ARG MOSQUITTO_VERSION
ARG PLUGIN_VERSION
ARG GO_VERSION

WORKDIR /app

#Get mosquitto build dependencies.
RUN apt-get update && apt-get install -y libwebsockets8 libwebsockets-dev libc-ares2 libc-ares-dev openssl uuid uuid-dev wget build-essential git
RUN mkdir -p mosquitto/auth mosquitto/conf.d

RUN wget http://mosquitto.org/files/source/mosquitto-${MOSQUITTO_VERSION}.tar.gz
RUN tar xzvf mosquitto-${MOSQUITTO_VERSION}.tar.gz && rm mosquitto-${MOSQUITTO_VERSION}.tar.gz 

#Build mosquitto.
RUN cd mosquitto-${MOSQUITTO_VERSION} && make -j$(nproc) WITH_WEBSOCKETS=yes && make install && cd ..

#Get Go.
RUN wget https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
RUN export PATH=$PATH:/usr/local/go/bin && go version && rm go${GO_VERSION}.linux-amd64.tar.gz

# Get the mosquitto-go-auth plugin
RUN wget https://github.com/iegomez/mosquitto-go-auth/archive/${PLUGIN_VERSION}.tar.gz && tar -xzf ${PLUGIN_VERSION}.tar.gz && rm ${PLUGIN_VERSION}.tar.gz

#Build the plugin.
RUN export PATH=$PATH:/usr/local/go/bin && export CGO_CFLAGS="-I/usr/local/include -fPIC" && export CGO_LDFLAGS="-shared" && cd mosquitto-go-auth-${PLUGIN_VERSION} && make -j$(nproc)


#Start from a new image.
FROM debian:stable-slim

ARG MOSQUITTO_VERSION
ARG PLUGIN_VERSION
ARG GO_VERSION

#Get mosquitto dependencies.
RUN apt-get update && apt-get install -y libwebsockets8 libc-ares2 openssl uuid

#Setup mosquitto env.
RUN mkdir -p /var/lib/mosquitto /var/log/mosquitto 
RUN groupadd mosquitto \
    && useradd -s /sbin/nologin mosquitto -g mosquitto -d /var/lib/mosquitto \
    && chown -R mosquitto:mosquitto /var/log/mosquitto/ \
    && chown -R mosquitto:mosquitto /var/lib/mosquitto/

#Copy confs, plugin so and mosquitto binary.
COPY --from=builder /app/mosquitto-go-auth-${PLUGIN_VERSION}/go-auth.so /etc/mosquitto/go-auth.so
COPY --from=builder /usr/local/sbin/mosquitto /usr/sbin/mosquitto

#Uncomment to copy your custom confs (change accordingly) directly when building the image.
#Leave commented if you want to mount a volume for these (see docker-compose.yml).
COPY ./mosquitto.conf /etc/mosquitto/mosquitto.conf

# Copy over keys/certificates generated from builder image
RUN mkdir /etc/mosquitto/certs

#Expose tcp and websocket ports as defined at mosquitto.conf (change accordingly).
EXPOSE 8883 9801

ENTRYPOINT ["sh", "-c", "/usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf" ]
