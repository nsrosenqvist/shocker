.POSIX:
SHELL=/bin/bash

NAME=shocker
VERSION=1.0.0
INSTALL_DIR=/usr/local/bin
FILE_NAME=$(NAME).sh
PKG_NAME=$(NAME)

all::
	@echo ""

docs:
	./shocker.sh -fx 1 -o docs/index.md shocker.sh

tag:
	git tag v$(VERSION)
	git push --tags

install:
	@echo "Installing $(NAME) $(VERSION)..."
	@echo

	mkdir -p "$(INSTALL_DIR)"
	cp "$(FILE_NAME)" "$(INSTALL_DIR)/$(PKG_NAME)"
	chmod 0755 "$(INSTALL_DIR)/$(PKG_NAME)"
	chmod +x "$(INSTALL_DIR)/$(PKG_NAME)"

	@echo
	@echo "$(NAME) $(VERSION) successfully installed to $(INSTALL_DIR)"

uninstall:
	rm -f "$(INSTALL_DIR)/$(PKG_NAME)"

.PHONY: tag install uninstall docs
