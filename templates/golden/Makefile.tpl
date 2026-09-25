# ============================================================================
# {{PROJECT}} — golden model Makefile
# ============================================================================
PYTHON ?= python3
TEST_DIR = vectors

.PHONY: vectors run manifest clean

vectors:
	@mkdir -p $(TEST_DIR)
	# TODO: generate input samples (or copy a reference set)
	$(PYTHON) model.py $(TEST_DIR)/input_samples.txt $(TEST_DIR)/golden_output.txt -v

# G-mod hash-lock (dv-flow.md): SHA-256 manifest over committed vectors.
# golden_check.sh verifies this before diffing; regenerate + commit whenever
# vectors change (also regenerating from a changed model.py).
manifest:
	cd $(TEST_DIR) && sha256sum V-*.exp > MANIFEST.sha256

run: vectors
	@echo "golden output in $(TEST_DIR)/golden_output.txt"

clean:
	rm -rf $(TEST_DIR) __pycache__
