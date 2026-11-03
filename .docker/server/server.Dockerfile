FROM golang:1.24 AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY server ./server
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /grimreach-server ./server

FROM scratch
COPY --from=build /grimreach-server /grimreach-server
USER 65532:65532
ENTRYPOINT ["/grimreach-server"]
