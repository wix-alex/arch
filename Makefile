REPO ?= $(shell cat repo_name)

.PHONY : default build_container manual container build shim push local

default: container

build_container:
	docker build -t arch meta

manual: build_container
	./meta/launch /bin/bash || true

container: build_container
	./meta/launch

build:
	$(eval rootfs := $(shell mktemp -d /build-XXXX))
	pacstrap -c -d -G $(rootfs) $$(cat packages)
	cd overlay && cp -R * $(rootfs)/
	arch-chroot $(rootfs) /bin/sh -c "pacman-key --init; pacman-key --populate; pkill gpg-agent"
	arch-chroot $(rootfs) locale-gen
	cd $(rootfs) && rm -rf etc/hosts etc/resolv.conf sys srv/{ftp,http} proc
	rm -f root.tar.bz2
	tar --numeric-owner -C $(rootfs) -cjf root.tar.bz2 .

shim:
	make -C shim

push:
	@echo $$(sed -r 's/[0-9]+$$//' version)$$(($$(sed -r 's/.*\.//' version) + 1)) > version
	sed -i "s|download/[0-9.]*/root|download/$$(cat version)/root|" Dockerfile
	git commit -am "$$(cat version)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$$(cat version)"
	git push origin "$$(cat version)"
	@sleep 5
	targit -a .github -c -f $(REPO) $$(cat version) root.tar.bz2
	@echo 'https://hub.docker.com/r/$(REPO)/builds/'
	git push origin master

local: build shim push

