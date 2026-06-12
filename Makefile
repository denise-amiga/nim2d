NIM ?= nim
OUT := docs/html
API := $(OUT)/api
GIT_URL := https://github.com/nim2d/nim2d
PAGES := index getting-started drawing input math data filesystem audio system physics examples

.PHONY: docs api pages shots format format-check clean serve

docs: api pages

# Backend modules get pages (so import links resolve) but stay out of the
# symbol index, which is for the public API.
api:
	@mkdir -p $(API)
	@for f in $$(find src -name '*.nim'); do \
		$(NIM) doc --hints:off --git.url:$(GIT_URL) --git.commit:master --git.devel:master --outdir:$(API) "$$f"; \
		case "$$f" in src/nim2d/backend/*) ;; *) $(NIM) doc --hints:off --index:only --outdir:$(API) "$$f";; esac; \
	done
	@$(NIM) buildIndex --hints:off --out:$(API)/theindex.html $(API)

pages:
	@mkdir -p $(OUT)/assets
	@cp docs/assets/*.png $(OUT)/assets/
	@for p in $(PAGES); do \
		$(NIM) md2html --hints:off --outdir:$(OUT) docs/$$p.md; \
		h1=$$(grep -m1 '^# ' docs/$$p.md | sed 's/^# *//'); \
		if [ "$$p" = "index" ]; then t="$$h1"; else t="$$h1 - nim2d"; fi; \
		tmp=$$(mktemp); \
		sed -e "s#<title>[^<]*</title>#<title>$$t</title>#" \
		    -e "s#<h1 class=\"title\">[^<]*</h1>#<h1 class=\"title\">$$t</h1>#" \
		    -e "s#<h1 id=\"[^\"]*\">[^<]*</h1>##" \
		    -e "s#<h1><a class=\"toc-backref\"[^>]*>[^<]*</a></h1>##" \
		    $(OUT)/$$p.html > $$tmp && mv $$tmp $(OUT)/$$p.html; \
	done

# Re-render the documentation screenshots into docs/assets. Opens a window and
# needs the SDL3 libraries plus Box2D (for the physics scene).
shots:
	@$(NIM) c -r --hints:off tools/docshots.nim

# Format every Nim source in place with nph (nimble install nph), or just
# report what would change.
format:
	@nph src tests examples tools

format-check:
	@nph --check src tests examples tools

clean:
	rm -rf $(OUT)

serve: docs
	@cd $(OUT) && python3 -m http.server 8000

include shaders.mk
