FROM golang:1.17

RUN apt-get update
RUN apt-get -y install git

RUN git clone https://github.com/ClusterCockpit/cc-metric-store.git /cc-metric-store
RUN cd /cc-metric-store && go build

# Reactivate when latest commit is available
#RUN go get -d -v github.com/ClusterCockpit/cc-metric-store
#RUN go install -v github.com/ClusterCockpit/cc-metric-store@latest

RUN mv /cc-metric-store/cc-metric-store /go/bin
COPY config.json  /go/bin

WORKDIR /go/bin
CMD ["./cc-metric-store"]
