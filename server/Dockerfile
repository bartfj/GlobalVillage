# 多阶段：编译原生可执行文件后打精简运行镜像
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

FROM debian:bookworm-slim AS runtime
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/bin/server /app/server
ENV PORT=8787
EXPOSE 8787
CMD ["/app/server"]
