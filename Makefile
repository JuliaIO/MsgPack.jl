DOCKER_IMAGE_NAME=test-msgpack
DOCKER_TAG=test


.PHONY: build
build:
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) .


.PHONY: julia
julia:
	docker run -it --rm $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) julia


.PHONY: test
test:
	docker run --rm $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

