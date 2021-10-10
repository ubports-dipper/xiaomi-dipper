#!/bin/bash
set -ex

SOURCES=$1

cd "$SOURCES"
cat > Makefile <<'EOF'
CFLAGS = -Ilibufdt/include -Ilibufdt/sysdeps/include -Idtc/libfdt
OBJS_APPLY = libufdt/tests/src/util.o libufdt/tests/src/ufdt_overlay_test_app.o
OBJS_UFDT = libufdt/ufdt_convert.o libufdt/ufdt_node_pool.o libufdt/ufdt_prop_dict.o libufdt/ufdt_node.o libufdt/ufdt_overlay.o libufdt/sysdeps/libufdt_sysdeps_posix.o
OBJS_FDT = dtc/libfdt/fdt_addresses.o dtc/libfdt/fdt_overlay.o dtc/libfdt/fdt_strerror.o dtc/libfdt/fdt.o dtc/libfdt/fdt_ro.o dtc/libfdt/fdt_sw.o dtc/libfdt/fdt_empty_tree.o dtc/libfdt/fdt_rw.o dtc/libfdt/fdt_wip.o

all: ufdt_apply_overlay

ufdt_apply_overlay: $(OBJS_APPLY) $(OBJS_UFDT) $(OBJS_FDT)
	$(CC) -o $@ $(LDFLAGS) $(OBJS_APPLY) $(OBJS_UFDT) $(OBJS_FDT)

clean:
	$(RM) ufdt_apply_overlay $(OBJS_APPLY) $(LDFLAGS) $(OBJS_UFDT) $(OBJS_FDT)
EOF

make ufdt_apply_overlay
