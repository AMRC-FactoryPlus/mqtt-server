# Factory+ MQTT Server Stack

This repo contains the docker configs for Factory+ mosquitto server builds. The two builds can share a common base image up to the point at which configs are applied, however I haven't figured out how to do that yet. For now, the two images are independent.

## Central
Central contains the docker files to create a "central" mosquitto broker which authenticates and authorizes clients using the central mysql service via the mosquitto-go-auth backend. The image requires CA signed certificates to exist on the central server where it is being built from. 

The configuration in mosquitto.conf is fairly straightforward and is baked into the image.

## Mosquitto-Go-Auth
Both images are configured to use the mosquitto-go-auth plugin which uses a central mysql instance for authentication, and authorization. They are configured to cache results for 30 seconds before requiring another database call, which can be configured in mosquitto.conf
