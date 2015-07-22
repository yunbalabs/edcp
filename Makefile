REBAR = ./rebar -j8

all: deps compile

compile: deps
	${REBAR} compile

deps:
	${REBAR} get-deps

clean:
	${REBAR} clean

generate: compile
	cd rel && ../${REBAR} generate -f

console: generate
	./rel/edcp/bin/edcp console

.PHONY: all deps clean
