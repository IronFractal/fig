.RECIPEPREFIX=>
SRCDIR=examples/
OUTDIR=build/

SCRIPTS=simple \
        example \
        non_path

SCRIPTS:=$(patsubst %,$(OUTDIR)%.sh,$(SCRIPTS))

all: $(OUTDIR).gitignore $(SCRIPTS)

$(OUTDIR).gitignore:
>@echo '*' > $@

$(OUTDIR)%.sh: $(SRCDIR)%.fig
>@echo "[GEN]: $@"
>@PATH="$$(pwd):$${PATH}" ./$^ "$$(pwd)/build"

.PHONY: clean
clean:
>@rm --verbose $(SCRIPTS)

