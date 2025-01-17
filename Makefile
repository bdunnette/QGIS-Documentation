# Makefile for Sphinx documentation
#

# as long as this branch is testing, we only build for english:
LANG          = en
SPHINXBUILD   ?= sphinx-build
SPHINXINTL    ?= sphinx-intl
PAPER         =
SOURCEDIR     = source
RESOURCEDIR   = static
BUILDDIR      = output
# using the -A flag, we create a python variable named 'language', which
# we then can use in html templates to create language dependent switches
SPHINXOPTS    = -D language=$(LANG) -A language=$(LANG) $(SOURCEDIR)
VERSION       = testing

# needed for python2 -> python3 migration?
export LC_ALL=C.UTF-8

# Internal variables.
PAPEROPT_a4     = -D latex_paper_size=a4
PAPEROPT_letter = -D latex_paper_size=letter
ALLSPHINXOPTS   = -d $(BUILDDIR)/doctrees $(PAPEROPT_$(PAPER)) $(SPHINXOPTS)
# the i18n builder cannot share the environment and doctrees with the others
I18NSPHINXOPTS  = $(PAPEROPT_$(PAPER)) $(SPHINXOPTS) i18n/pot

.PHONY: help clean html dirhtml singlehtml pickle json htmlhelp qthelp devhelp epub latex latexpdf text man changes linkcheck doctest gettext

help:
	@echo "  "
	@echo "Please use \`make <target> LANG=xx' where xx=language code and <target> is one of:"
	@echo "  html         to build the website as html for enlish only"
	@echo "  fullhtml     to pull QGIS-Documentation from github and build into the website"
	@echo "  world        to create the website for ALL available languages"
	@echo "  clean        to clean up all intermediate files"
	@echo "  springclean  to also remove build output besides normal clean"
	@echo "  createlang   to create (mostly directories) for a new language"
	@echo "  pretranslate to gather all strings from sources, put in .pot files"
	@echo "                  AND merge them with available .po files"
	@echo "  transifex_push (only for transifex Maintainers!): renew source files and push to transifex"
	@echo "  doctest     to run all doctests embedded in the documentation (if enabled)"
	@echo "  "
	@echo "OPTION: use LANG=xx to do it only for one language, eg: make html LANG=de"
	@echo "  "

clean:
	rm -rf $(SOURCEDIR)/static
	rm -rf $(BUILDDIR)/*

springclean: clean
	# something in i18n/pot dir creates havoc when using gettext: remove it
	rm -rf i18n/pot
	# all .mo files
	find i18n/*/LC_MESSAGES/ -type f -name '*.mo' -delete
	# rm -rf i18n/*/LC_MESSAGES/docs/*/
	# rm -f $(SOURCEDIR)/docs_conf.py*
	# rm -rf $(SOURCEDIR)/docs/*/

updatestatic:
	@echo
	@echo "Updating static content into $(SOURCEDIR)/static."
	rsync -uthvr --delete $(RESOURCEDIR)/ $(SOURCEDIR)/static

html: updatestatic
	$(SPHINXINTL) --config $(SOURCEDIR)/conf.py build --language=$(LANG)
	# ONLY in the english version run in nit-picky mode, so source errors/warnings will fail in Travis
	#  -n   Run in nit-picky mode. Currently, this generates warnings for all missing references.
	#  -W   Turn warnings into errors. This means that the build stops at the first warning and sphinx-build exits with exit status 1.
	@if [ $(LANG) != "en" ]; then \
		$(SPHINXBUILD) -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html/$(LANG); \
	else \
		$(SPHINXBUILD) -n -W -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html/$(LANG); \
	fi
	@echo
	@echo "HTML Build finished. The HTML pages for '$(LANG)' are in $(BUILDDIR)."

# pdf will also make html
pdf: html
	# add the 'processing algorithms' part OUT of the pdf by adding it to exclude_patterns of build
	# NOTE: this exclusion line will be removed in docker-world.sh via a git checkout!
	@echo "exclude_patterns += ['docs/user_manual/processing_algs/*']" >> $(SOURCEDIR)/conf.py;

	@if [ $(LANG) = "ko" -o $(LANG) = "hi" ]; then \
		cp -f $(SOURCEDIR)/conf.py $(SOURCEDIR)/i18n/$(LANG)/; \
		cat $(SOURCEDIR)/i18n/$(LANG)/conf.py.diff >> $(SOURCEDIR)/i18n/$(LANG)/conf.py; \
		$(SPHINXBUILD) -b latex -c $(SOURCEDIR)/i18n/$(LANG) $(ALLSPHINXOPTS) $(BUILDDIR)/latex/$(LANG); \
	else \
		$(SPHINXBUILD) -b latex $(ALLSPHINXOPTS) $(BUILDDIR)/latex/$(LANG); \
	fi
	# Compile the pdf docs for that locale
	# we use texi2pdf since latexpdf target is not available via
	# sphinx-build which we need to use since we need to pass language flag
	mkdir -p $(BUILDDIR)/pdf/$(LANG)
	# need to build 3x to have proper toc and index
	# currently texi2pdf has bad exit status. Please ignore errors!!
	# prepending the texi2pdf command with - keeps make going instead of quitting
	# japanese pdf has problems, when build with texi2pdf
	# as alternative we can use platex
	# for russian pdf you need package 'texlive-lang-cyrillic' installed
	# for japanese pdf you need: 'cmap-adobe-japan1 cmap-adobe-japan2 latex-cjk-all nkf okumura-clsfiles ptex-base ptex-bin texlive-fonts-extra'
	@-if [ $(LANG) = "ja" ]; then \
		cd $(BUILDDIR)/latex/$(LANG); \
		nkf -W -e --overwrite QGISUserGuide.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape QGISUserGuide.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape QGISUserGuide.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape QGISUserGuide.tex; \
		dvipdfmx QGISUserGuide.dvi; \
	elif [ $(LANG) = "ko" -o $(LANG) = "hi" ]; then \
		cd $(BUILDDIR)/latex/$(LANG); \
		xelatex -interaction=batchmode --no-pdf -shell-escape QGISUserGuide.tex; \
		xelatex -interaction=batchmode --no-pdf -shell-escape QGISUserGuide.tex; \
		xelatex -interaction=batchmode --no-pdf -shell-escape QGISUserGuide.tex; \
		xdvipdfmx QGISUserGuide.xdv; \
	else \
		cd $(BUILDDIR)/latex/$(LANG); \
		texi2pdf --quiet QGISUserGuide.tex; \
		texi2pdf --quiet QGISUserGuide.tex; \
		texi2pdf --quiet QGISUserGuide.tex; \
	fi
	mv $(BUILDDIR)/latex/$(LANG)/QGISUserGuide.pdf $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-UserGuide.pdf
	# pyqgis developer cookbook
	@-if [ $(LANG) = "ja" ]; then \
		cd $(BUILDDIR)/latex/$(LANG); \
		nkf -W -e --overwrite PyQGISDeveloperCookbook.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape PyQGISDeveloperCookbook.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape PyQGISDeveloperCookbook.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape PyQGISDeveloperCookbook.tex; \
		dvipdfmx PyQGISDeveloperCookbook.dvi; \
	elif [ $(LANG) = "ko" -o $(LANG) = "hi" ]; then \
		cd $(BUILDDIR)/latex/$(LANG); \
		xelatex -interaction=batchmode --no-pdf -shell-escape PyQGISDeveloperCookbook.tex; \
		xelatex -interaction=batchmode --no-pdf -shell-escape PyQGISDeveloperCookbook.tex; \
		xelatex -interaction=batchmode --no-pdf -shell-escape PyQGISDeveloperCookbook.tex; \
		xdvipdfmx PyQGISDeveloperCookbook.xdv; \
	else \
		cd $(BUILDDIR)/latex/$(LANG); \
		texi2pdf --quiet PyQGISDeveloperCookbook.tex; \
		texi2pdf --quiet PyQGISDeveloperCookbook.tex; \
		texi2pdf --quiet PyQGISDeveloperCookbook.tex; \
	fi
	mv $(BUILDDIR)/latex/$(LANG)/PyQGISDeveloperCookbook.pdf $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-PyQGISDeveloperCookbook.pdf
	# training manual
	@-if [ $(LANG) = "ja" ]; then \
		cd $(BUILDDIR)/latex/$(LANG); \
		nkf -W -e --overwrite QGISTrainingManual.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape QGISTrainingManual.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape QGISTrainingManual.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape QGISTrainingManual.tex; \
		dvipdfmx QGISTrainingManual.dvi; \
	elif [ $(LANG) = "ko" -o $(LANG) = "hi" ]; then \
		cd $(BUILDDIR)/latex/$(LANG); \
		xelatex -interaction=batchmode --no-pdf -shell-escape QGISTrainingManual.tex; \
		xelatex -interaction=batchmode --no-pdf -shell-escape QGISTrainingManual.tex; \
		xelatex -interaction=batchmode --no-pdf -shell-escape QGISTrainingManual.tex; \
		xdvipdfmx QGISTrainingManual.xdv; \
	else \
		cd $(BUILDDIR)/latex/$(LANG); \
		texi2pdf --quiet QGISTrainingManual.tex; \
		texi2pdf --quiet QGISTrainingManual.tex; \
		texi2pdf --quiet QGISTrainingManual.tex; \
	fi
	mv $(BUILDDIR)/latex/$(LANG)/QGISTrainingManual.pdf $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-QGISTrainingManual.pdf
	# developer guidelines
	@-if [ $(LANG) = "ja" ]; then \
		cd $(BUILDDIR)/latex/$(LANG); \
		nkf -W -e --overwrite QGISDevelopersGuide.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape QGISDevelopersGuide.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape QGISDevelopersGuide.tex; \
		platex -interaction=batchmode -kanji=euc -shell-escape QGISDevelopersGuide.tex; \
		dvipdfmx QGISDevelopersGuide.dvi; \
	elif [ $(LANG) = "ko" -o $(LANG) = "hi" ]; then \
		cd $(BUILDDIR)/latex/$(LANG); \
		xelatex -interaction=batchmode --no-pdf -shell-escape QGISDevelopersGuide.tex; \
		xelatex -interaction=batchmode --no-pdf -shell-escape QGISDevelopersGuide.tex; \
		xelatex -interaction=batchmode --no-pdf -shell-escape QGISDevelopersGuide.tex; \
		xdvipdfmx QGISDevelopersGuide.xdv; \
	else \
		cd $(BUILDDIR)/latex/$(LANG); \
		texi2pdf --quiet QGISDevelopersGuide.tex; \
		texi2pdf --quiet QGISDevelopersGuide.tex; \
		texi2pdf --quiet QGISDevelopersGuide.tex; \
	fi
	mv $(BUILDDIR)/latex/$(LANG)/QGISDevelopersGuide.pdf $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-QGISDevelopersGuide.pdf

full:  
#	@-if [ $(LANG) != "en" ]; then \
#		echo; \
#		echo Pulling $$LANG from transifex; \
#		# --minimum-perc=1 so only files which have at least 1% translation are pulled \
#		# -f to force, --skip to not stop with errors \
#		# -l lang \
#		echo tx pull --minimum-perc=1 --skip -f -l $$LANG; \
#        fi
	make pdf
	mv $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-UserGuide.pdf $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-UserGuide-$(LANG).pdf
	mv $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-PyQGISDeveloperCookbook.pdf $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-PyQGISDeveloperCookbook-$(LANG).pdf
	mv $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-QGISTrainingManual.pdf $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-QGISTrainingManual-$(LANG).pdf
	mv $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-QGISDevelopersGuide.pdf $(BUILDDIR)/pdf/$(LANG)/QGIS-$(VERSION)-QGISDevelopersGuide-$(LANG).pdf

world: all

all: full

createlang: springclean
	@echo Creating a new Language: $(LANG)
	mkdir -p resources/${LANG}/docs
	cp resources/en/README resources/${LANG}
	cp resources/en/README resources/${LANG}/docs
	mkdir -p i18n/${LANG}/LC_MESSAGES/docs
	cp i18n/en/README i18n/${LANG}
	cp i18n/en/README i18n/${LANG}/LC_MESSAGES/docs

pretranslate: gettext
	@echo "Generating the pot files for the QGIS-Documentation project"
	$(SPHINXINTL) update -p i18n/pot -l $(LANG)

gettext:
	# something in i18n/pot dir creates havoc when using gettext: remove it
	rm -rf i18n/pot
	$(SPHINXBUILD) -b gettext $(I18NSPHINXOPTS)
	@echo
	@echo "Build finished. The message catalogs are in $(BUILDDIR)/locale."



# ONLY to be done by a transifex Maintainer for the project, as it overwrites
# the english source resources
# 1) make springclean (removing all building cruft)
# 2) make pretranslate (getting all strings from sources and create new pot files)
# 3) tx push -fs --no-interactive (push the source (-f) files forcing (-f) overwriting the ones their without asking (--no-interactive)
#
# SHOULD NOT BE DONE ON TESTING/MASTER BRANCH! ONLY ON STABLE==TRANSLATING BRANCH
#transifex_push:
#	make springclean
#	make pretranslate
#	tx push -f -s --no-interactive

fasthtml: updatestatic
	# This build is just for fast previewing changes in EN documentation
	# It runs in non-nit-picky mode allowing to check all warnings without
	# cancelling the build
	# No internationalization is performed
	$(SPHINXBUILD) -n -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html/$(LANG)

linkcheck:
	$(SPHINXBUILD) -n -b linkcheck $(ALLSPHINXOPTS) $(BUILDDIR)/linkcheck
	@echo
	@echo "Check finished. Report is in $(BUILDDIR)/linkcheck/output.txt".

doctest:
	$(SPHINXBUILD) -b doctest $(ALLSPHINXOPTS) $(BUILDDIR)/doctest
	@echo "Testing of doctests in the sources finished, look at the " \
	      "results in $(BUILDDIR)/doctest/output.txt."
