#
# Makefile
#

# ldflags variables to update --version
# short commit hash
COMMIT :=$(shell /usr/bin/git describe --always)
DATE :=$(shell /bin/date -u +"%Y-%m-%d-%H:%M")
BINARY :=run_qdiscs_tests

all: clean build version

test:
	go test

clean:
	[ -f ${BINARY} ] && /bin/rm -rf ./${BINARY} || true

build:
	CGO_ENABLED=0 go build -ldflags "-X main.commit=${COMMIT} -X main.date=${DATE}" -o ./${BINARY} ./${BINARY}.go

# https://words.filippo.io/shrink-your-go-binaries-with-this-one-weird-trick/
buildsmall:
	CGO_ENABLED=0 go build -ldflags "-s -w -X main.commit=${COMMIT} -X main.date=${DATE}" -o ./${BINARY} ./${BINARY}.go

shrink:
	upx --brute ./${BINARY}

version:
	./${BINARY} --version

go:
	make && ./${BINARY} -dontReboot

go3rd:
	./${BINARY} -dontReboot -cakePath /home/das/cake

bc: build copy

copy:
	scp ./${BINARY} 3rd:/home/das/Downloads/cake/cmd/run_qdiscs_tests

clear_tmp_qdisc:
	sudo rm -rf /tmp/qdisc/

curl_metrics:
	curl --silent http://3rd:9111/metrics | grep tester | grep count
#