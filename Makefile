.PHONY: all clean lint clean check-lint utop hell ligo test-ligo

all: hell
	dune build

clean:
	dune clean

lint:
	dune build @fmt --auto-promote

check-lint:
	dune build @fmt

utop:
	dune utop lib

hell:
	(cd hell; npm install; npm run build)

%.tez: contracts/%/main.mligo
	mkdir -p _build/contracts
	ligo compile contract $(^) > _build/contracts/$(@)

ligo: benefactor.tez

test-ligo: ligo
	(cd contracts; ligo run test test.mligo)
