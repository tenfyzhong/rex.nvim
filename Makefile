.PHONY: test

test:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }"
	python3 -m unittest discover -s tests -p 'test_*.py' -v
