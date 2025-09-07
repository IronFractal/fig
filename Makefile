.RECIPEPREFIX=>
SRCDIR=examples/
OUTDIR=build/

SCRIPTS=simple \
        example \
        non_path \
        progress

SCRIPTS:=$(patsubst %,$(OUTDIR)%.sh,$(SCRIPTS))

all: $(OUTDIR).gitignore $(SCRIPTS)

$(OUTDIR).gitignore:
>@echo '*' > $@

$(OUTDIR)%.sh: $(SRCDIR)%.fig fig.sh
>@echo "[GEN]: $@"
>@PATH="$$(pwd):$${PATH}" FIG_ALLOW_OVERWRITE=true ./$< "$$(pwd)/build"

.PHONY: clean
clean:
>@rm --force --verbose $(SCRIPTS)

