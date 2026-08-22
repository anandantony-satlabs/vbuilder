# ============================================================================
# {{PROJECT}} — golden model Makefile
# ============================================================================
PYTHON ?= python3
TEST_DIR = vectors

.PHONY: vectors run clean

vectors:
	@mkdir -p $(TEST_DIR)
	# TODO: generate input samples (or copy a reference set)
	$(PYTHON) model.py $(TEST_DIR)/input_samples.txt $(TEST_DIR)/golden_output.txt -v

run: vectors
	@echo "golden output in $(TEST_DIR)/golden_output.txt"

clean:
	rm -rf $(TEST_DIR) __pycache__
