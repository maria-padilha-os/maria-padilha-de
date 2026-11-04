.PHONY: test lint docs package

test:
	bash tests/all.sh

lint:
	bash tools/lint.sh

docs:
	tools/docs-preview build --source docs --destination .scratch/docs-site --baseurl ""

package:
	tools/release.sh
