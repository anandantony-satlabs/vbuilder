# ============================================================================
# vbuilder DV Flow — contract.mk
# ============================================================================
# Loads and validates the "DV contract" that a vbuilder project maintains:
#   - dv/filelist.f  : ordered compile list (pkg first, top last)
#   - TESTS          : whitespace-separated test class names
#   - TB_TOP         : top-level testbench module
#
# vbuilder's add_module / add_test actions maintain filelist.f ordering and
# the pkg `include anchors so this loader just reads + sanity-checks.
# ============================================================================

FILELIST ?= filelist.f

# Read the ordered source list from filelist.f (preserve order, strip comments).
# Uses make's $(file ...) when available, else shell fallback.
ifeq ($(wildcard $(FILELIST)),)
$(error filelist.f not found at $(FILELIST). Run `vbuilder init` or create it. \
The filelist must list, in order: *_pkg.sv -> components -> tests -> tb_top.)
endif

# Resolve the filelist into SV_SRCS (order-preserved, comments stripped).
SV_SRCS := $(shell sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e '/^$$/d' $(FILELIST))

# Validation: the first .sv that is *_pkg.sv must come before any non-pkg .sv.
# (IEEE 1800-2017 26.3: a package must be declared before use.)
define _check_pkg_order
$(if $(filter-out $(words $(filter %_pkg.sv,$(SV_SRCS))),0),\
  $(if $(filter-out $(filter %_pkg.sv,$(word 1,$(SV_SRCS))),$(word 1,$(SV_SRCS))),\
    $(warning [flow] filelist.f: first source is not a *_pkg.sv — package \
may be undeclared at compile (IEEE 1800-2017 26.3). Verify ordering.)))
endef
$(eval $(_check_pkg_order))

# TESTS must contain at least the sanity test.
ifndef TESTS
$(warning [flow] TESTS is empty — `make regression` will do nothing. \
Add tests with: vbuilder add-test <name>)
endif

# Export for backends.
export SV_SRCS
