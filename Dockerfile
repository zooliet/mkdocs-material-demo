# syntax = docker/dockerfile:1

# Make sure it matches the Ruby version in .ruby-version and Gemfile
ARG PYTHON_VERSION=3.10
FROM python:$PYTHON_VERSION-slim as base

# Maintainer
LABEL maintainer="Junhyun Shin <hl1sqi@gmail.com>"

# MkDocs app lives here
WORKDIR /mkdocs

FROM base as build

RUN pip install mkdocs mkdocs-material
COPY . .
RUN mkdocs build

FROM base

# Run and own the application files as a non-root user for security
RUN useradd deploy
USER deploy:deploy

COPY --from=build --chown=deploy:deploy /mkdocs /mkdocs
COPY --from=build --chown=deploy:deploy /mkdocs/blogs /blogs

ENTRYPOINT ["./docker-entrypoint"]

EXPOSE 8000
CMD ["mkdocs", "serve"]
