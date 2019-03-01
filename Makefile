CPANFILE_SNAPSHOT := $(shell \
  carton exec perl -MFile::Spec -e \
	'($$_) = grep { -e } map{ "$$_/../../cpanfile.snapshot" } \
		grep { m(/lib/perl5$$) } @INC; \
		print File::Spec->abs2rel($$_) . "\n" if $$_' 2>/dev/null )

ifndef CPANFILE_SNAPSHOT
	CPANFILE_SNAPSHOT := .MAKE
endif

.PHONY : test REQUIRE_CARTON

test : REQUIRE_CARTON $(CPANFILE_SNAPSHOT)
	@nice carton exec prove -lfr t

# This target requires that you add 'requires "Devel::Cover";'
# to the cpanfile and then run "carton" to install it.
testcoverage : $(CPANFILE_SNAPSHOT)
	carton exec -- cover -test -ignore . -select ^lib

$(CPANFILE_SNAPSHOT): cpanfile
	carton install

REQUIRE_CARTON:
	@if ! carton --version >/dev/null 2>&1 ; then \
		echo You must install carton: https://metacpan.org/pod/Carton >&2; \
		false; \
	else \
		true; \
	fi
