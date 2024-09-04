# syntax=docker/dockerfile:1

FROM debian:trixie

ARG BUILD_TIMESTAMP

COPY . .
RUN bash ./build.sh
