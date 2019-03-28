SHARE_DIR   := $(shell \
	carton exec perl -Ilib -MFile::ShareDir=dist_dir -e \
		'print eval { dist_dir("Dist-Zilla-PluginBundle-Author-GSG") } || "share"' )

include $(SHARE_DIR)/Makefile

# Copy the SHARE_DIR Makefile over this one:
# Making it .PHONY will force it to copy even if this one is newer.
.PHONY: Makefile
Makefile: $(SHARE_DIR)/Makefile
	cp $< $@
