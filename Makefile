-include .env

.PHONY: build 

build:; forge build

test:; forge test 

test-one: 
	@read -p "Enter test function name (e.g., testItReverts): " test; \
	forge test --match-test $$test 


test-onev5: 
	@read -p "Enter test function name (e.g., testItReverts): " test; \
	forge test --match-test $$test -vvvvv

test-onev4: 
	@read -p "Enter test function name (e.g., testItReverts): " test; \
	forge test --match-test $$test -vvvv


test-onev3: 
	@read -p "Enter test function name (e.g., testItReverts): " test; \
	forge test --match-test $$test -vvv

test-onev2: 
	@read -p "Enter test function name (e.g., testItReverts): " test; \
	forge test --match-test $$test -vv


coverage-r:; forge coverage --report debug > coverage.txt