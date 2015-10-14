SHELL = bash
CONSOLE_ELM = $(shell find elm-console/ -type f -name '*.elm')
CONSOLE_JS = $(shell find elm-console/ -type f -name '*.js')

all: build/elmit.js build/parser.js

init:
	git submodule init
	git submodule update
	elm-package install -y
	npm install jison

build:
	mkdir -p $@


build/main.js: src/Main.elm src/Parser.elm build/parser.js build \
		$(CONSOLE_JS) \
		$(CONSOLE_ELM)
	elm-make $< --output $@

build/elmit.js: build/main.js build
	elm-console/elm-io.sh $< $@

build/parser.js: grammar/elmit.jison grammar/append.js build
	node_modules/.bin/jison -m js $< -o $@
	cat grammar/append.js >> $@


test: build/elmit.js
	@test "`cat test/simple.html | node build/elmit.js`" \
		= "`cat test/simple.elm`" && echo -n . || echo "Failed: simple.html"
	@echo


.PHONY: all clean test

clean:
	rm -rf build src/Native/Parser.js
