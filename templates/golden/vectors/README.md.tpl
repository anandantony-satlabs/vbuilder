# {{MODULE}} golden vectors
#
# This directory holds the executable-spec output of golden/model.py.
# Per FACTORY.md §5.1, ship BOTH:
#   - golden_output.txt        : clean reference vectors
#   - error_injected/          : corrupted inputs with known-correctable positions
#                               (needed to validate any RX-side decoder, e.g. BM t=16)
#
# The golden model must clear its own validation gate (reproduce a published
# reference vector) before RTL is checked against these files.
