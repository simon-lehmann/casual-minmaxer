LUA_HOME ?= $(HOME)/.local
export LUA_PATH := $(LUA_HOME)/share/lua/5.1/?.lua;$(LUA_HOME)/share/lua/5.1/?/init.lua;;
export LUA_CPATH := $(LUA_HOME)/lib/lua/5.1/?.so;;
BUSTED ?= $(LUA_HOME)/bin/busted
LUACHECK ?= $(LUA_HOME)/bin/luacheck
VERSION ?= $(shell git describe --tags --always 2>/dev/null || echo dev)

.PHONY: test lint data data-snapshot pytest package all check

all: check

check: lint test pytest

test:
	$(BUSTED) --verbose tests/spec

lint:
	$(LUACHECK) CasualMinMaxer tests --no-color

data-snapshot:
	python3 pipeline/extract_sqlite.py

data:
	python3 pipeline/build.py

pytest:
	python3 -m pytest -q pipeline/tests

package:
	scripts/package.sh $(VERSION)
