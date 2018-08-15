
include env_make

NS       = bodsch
VERSION ?= latest

REPO     = docker-graphite
NAME     = graphite
INSTANCE = default

BUILD_DATE        := $(shell date +%Y-%m-%d)
BUILD_VERSION     := $(shell date +%y%m)
BUILD_TYPE        ?= stable
GRAPHITE_VERSION  ?= 1.1.3
PYTHON_VERSION    ?= 2


.PHONY: build push shell run start stop rm release params

build:	params
	docker build \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg BUILD_TYPE=$(BUILD_TYPE) \
		--build-arg GRAPHITE_VERSION=${GRAPHITE_VERSION} \
		--build-arg PYTHON_VERSION=${PYTHON_VERSION} \
		--tag $(NS)/$(REPO):$(GRAPHITE_VERSION) .

clean:
	docker rmi \
		--force \
		$(NS)/$(REPO):$(GRAPHITE_VERSION)

history:
	docker history \
		$(NS)/$(REPO):$(GRAPHITE_VERSION)

push:
	docker push \
		$(NS)/$(REPO):$(GRAPHITE_VERSION)

shell:
	docker run \
		--rm \
		--name $(NAME)-$(INSTANCE) \
		--interactive \
		--tty \
		$(PORTS) \
		$(VOLUMES) \
		$(ENV) \
		$(NS)/$(REPO):$(GRAPHITE_VERSION) \
		/bin/sh

run:
	docker run \
		--rm \
		--name $(NAME)-$(INSTANCE) \
		$(PORTS) \
		$(VOLUMES) \
		$(ENV) \
		$(NS)/$(REPO):$(GRAPHITE_VERSION)

exec:
	docker exec \
		--interactive \
		--tty \
		$(NAME)-$(INSTANCE) \
		/bin/sh

start:
	docker run \
		--detach \
		--name $(NAME)-$(INSTANCE) \
		$(PORTS) \
		$(VOLUMES) \
		$(ENV) \
		$(NS)/$(REPO):$(GRAPHITE_VERSION)

stop:
	docker stop \
		$(NAME)-$(INSTANCE)

rm:
	docker rm \
		$(NAME)-$(INSTANCE)

release: build
	make push -e VERSION=$(GRAPHITE_VERSION)


params:
	@echo ""
	@echo " GRAPHITE_VERSION : ${GRAPHITE_VERSION}"
	@echo " PYTHON_VERSION   : ${PYTHON_VERSION}"
	@echo " BUILD_DATE       : $(BUILD_DATE)"
	@echo " BUILD_VERSION    : $(BUILD_VERSION)"
	@echo " BUILD_TYPE       : $(BUILD_TYPE)"
	@echo ""


default: build
