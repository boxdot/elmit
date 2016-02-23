SHELL = bash

all: build/elmit.js

init:
	elm-package install -y
	npm install jison

build:
	mkdir -p $@


build/main.js: src/Main.elm src/Parser.elm build/parser.js build
	elm-make $< --output $@

build/parser.js: grammar/elmit.jison grammar/append.js build
	node_modules/.bin/jison -m js $< -o $@
	cat grammar/append.js >> $@

build/elmit.js: build/main.js build/parser.js
	cp $< $@ && cat runner.js >> $@


test: build/elmit.js
	@test "`cat test/simple.html | node build/elmit.js`" \
		= "`cat test/simple.elm`" && echo -n . || echo "Failed: simple.html"
	@echo


.PHONY: all clean test

clean:
	rm -rf build
