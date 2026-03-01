lua_fmt:
	echo "===> Formatting"
	stylua lua/co --config-path=.stylua.toml

lua_fmt_check:
	echo "===> Checking format"
	stylua lua/co --config-path=.stylua.toml --check

lua_lint:
	echo "===> Linting"
	luacheck lua/co --globals vim

lua_test:
	echo "===> Testing"
	nvim --headless --noplugin -u scripts/tests/minimal.vim \
        -c "PlenaryBustedDirectory lua/co {minimal_init = 'scripts/tests/minimal.vim'}"

lua_clean:
	echo "===> Cleaning"
	find ./tmp -maxdepth 1 -type f -name 'co-*' -delete 2>/dev/null || true

pr_ready: lua_lint lua_test lua_fmt_check

all:
	$(MAKE) lua_fmt_check
	$(MAKE) lua_lint
	$(MAKE) lua_test
	$(MAKE) lua_clean
