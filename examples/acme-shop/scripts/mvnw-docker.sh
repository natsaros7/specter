#!/bin/sh
# Runs ./mvnw in a container so Maven never touches the host: sh scripts/mvnw-docker.sh -B verify
# Run it from examples/acme-shop. The source is mounted read-only and copied to the container's /tmp (host
# scanners slow bind-mount writes); ~/.m2 lives in a named volume, so later runs work offline (-o).
# ACME_IMAGE: the JDK 21 image. Alpine is the small default; if protoc or protoc-gen-grpc-java will not exec
#   (glibc binaries on musl), use ACME_IMAGE=azul/zulu-openjdk:21.
# ACME_NETWORK: docker network, default bridge; "none" for a fully offline run (the volume must be filled).
# shortcut: image tag not pinned by digest, pin it when CI uses this.
set -u
image=${ACME_IMAGE:-azul/zulu-openjdk-alpine:21}
exec docker run --rm --memory 3g --network "${ACME_NETWORK:-bridge}" \
    -v "$PWD":/src:ro -v specter-acme-m2:/root/.m2 "$image" sh -c \
    '[ -f /src/mvnw ] || { echo "mvnw-docker: /src is empty (run from examples/acme-shop; does your container runtime share this path?)" >&2; exit 2; }
     cp -R /src /tmp/a && cd /tmp/a && ./mvnw "$@"' sh "$@"
