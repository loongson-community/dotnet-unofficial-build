# syntax=docker/dockerfile:1

FROM debian:trixie-20240904

ARG BUILD_TIMESTAMP
ARG BUILDER_USER=b
ARG BUILDER_UID=1000

COPY . .
RUN ./build.sh
