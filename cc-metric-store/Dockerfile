FROM golang:1.22.4

RUN apt-get update
RUN apt-get -y install git

RUN rm -rf /cc-metric-store

RUN git clone https://github.com/ClusterCockpit/cc-metric-store.git /cc-metric-store
RUN cd /cc-metric-store && go build ./cmd/cc-metric-store

# Reactivate when latest commit is available
#RUN go get -d -v github.com/ClusterCockpit/cc-metric-store
#RUN go install -v github.com/ClusterCockpit/cc-metric-store@latest

RUN mv /cc-metric-store/cc-metric-store /go/bin
COPY config.json  /go/bin

VOLUME /data

WORKDIR /go/bin
CMD ["./cc-metric-store"]
