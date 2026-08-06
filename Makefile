IMAGE := k8s-helm-util-test:local

.PHONY: test
test: build
	docker run --rm -v $(PWD):/workspace $(IMAGE) ./tests/run_tests.sh

.PHONY: lint
lint: shellcheck

.PHONY: shellcheck
shellcheck: build
	docker run --rm -v $(PWD):/workspace $(IMAGE) shellcheck -x *.sh tests/*.sh scripts/*.sh

.PHONY: build
build:
	docker build -t $(IMAGE) .
