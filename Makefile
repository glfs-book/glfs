# vim:ts=3
# Makefile for GLFS Book generation.
# By Tushar Teredesai <tushar@linuxfromscratch.org>
# 2004-01-31

# Adjust these to suit your installation
RENDERTMP   ?= /tmp
CHUNK_QUIET  = 1
ROOT_ID      =
SHELL        = /bin/bash

ALLXML := $(filter-out $(RENDERTMP)/%, \
	$(wildcard *.xml */*.xml */*/*.xml */*/*/*.xml */*/*/*/*.xml))
ALLXSL := $(filter-out $(RENDERTMP)/%, \
	$(wildcard *.xsl */*.xsl */*/*.xsl */*/*/*.xsl */*/*/*/*.xsl))

ifdef V
  Q =
else
  Q = @
endif

ifndef REV
  REV = sysv
endif

ifneq ($(REV), sysv)
  ifneq ($(REV), systemd)
    $(error REV must be 'sysv' (default) or 'systemd'.)
  endif
endif

ifeq ($(REV), sysv)
  BASEDIR         ?= xxx
  PDF_OUTPUT      ?= glfs.pdf
  NOCHUNKS_OUTPUT ?= glfs.html
  DUMPDIR         ?= ~/glfs-commands
  GLFSHTML        ?= glfs-html.xml
  GLFSHTML2       ?= glfs-html2.xml
  GLFSFULL        ?= glfs-full.xml
else
  BASEDIR         ?= xxx/glfs-systemd
  PDF_OUTPUT      ?= glfs-sysd.pdf
  NOCHUNKS_OUTPUT ?= glfs-sysd.html
  DUMPDIR         ?= ~/glfs-sysd-commands
  GLFSHTML        ?= glfs-systemd-html.xml
  GLFSHTML2       ?= glfs-systemd-html2.xml
  GLFSFULL        ?= glfs-systemd-full.xml

endif

glfs: html wget-list

help:
	@echo ""
	@echo "make <parameters> <targets>"
	@echo ""
	@echo "Parameters:"
	@echo "  REV=<rev>            Build variation of book"
	@echo "                       Valid values for REV are:"
	@echo "                       * sysv    - Build book for SysV"
	@echo "                       * systemd - Build book for systemd"
	@echo "                       Defaults to 'sysv'"
	@echo ""
	@echo "  BASEDIR=<dir>        Put the output in directory <dir>."
	@echo "                       Defaults to"
	@echo "                       'HOME/public_html/glfs' if REV=sysv (or unset)"
	@echo "                       or to"
	@echo "                       'HOME/public_html/glfs-systemd' if REV=systemd"
	@echo ""
	@echo "  V=<val>              If <val> is a non-empty value, all"
	@echo "                       steps to produce the output is shown."
	@echo "                       Default is unset."
	@echo ""
	@echo "Targets:"
	@echo "  help                 Show this help text."
	@echo ""
	@echo "  glfs            Builds targets 'html' and 'wget-list'."
	@echo ""
	@echo "  html                 Builds the HTML pages of the book."
	@echo ""
	@echo "	pdf						Builds the book as a PDF file."
	@echo ""
	@echo "  wget-list            Produces a list of all packages to download."
	@echo "                       Output is BASEDIR/wget-list"
	@echo ""
	@echo "  nochunks             Builds the book as a one-pager. The output"
	@echo "                       is a large single HTML page containing the"
	@echo "                       whole book."
	@echo ""
	@echo "                       Parameter NOCHUNKS_OUTPUT=<filename> controls"
	@echo "                       the name of the HTML file."
	@echo ""
	@echo "  validate             Runs validation checks on the XML files."
	@echo ""
	@echo "  test-links           Runs validation checks on URLs in the book."
	@echo "                       Produces a file named BASEDIR/bad_urls containing"
	@echo "                       URLS which are invalid and a BASEDIR/good_urls"
	@echo "                       containing all valid URLs."
	@echo ""

all: glfs nochunks
world: all glfs-patch-list dump-commands test-links

html: $(BASEDIR)/index.html
$(BASEDIR)/index.html: $(RENDERTMP)/$(GLFSHTML) version
	@echo "Generating chunked XHTML files..."
	$(Q)xsltproc --nonet                                    \
                --stringparam chunk.quietly $(CHUNK_QUIET) \
                --stringparam rootid "$(ROOT_ID)"          \
                --stringparam base.dir $(BASEDIR)/         \
                stylesheets/glfs-chunked.xsl               \
                $(RENDERTMP)/$(GLFSHTML)

	@echo "Copying CSS code and images..."
	$(Q)if [ ! -e $(BASEDIR)/stylesheets ]; then \
      mkdir -p $(BASEDIR)/stylesheets;          \
   fi;

	$(Q)cp stylesheets/lfs-xsl/*.css $(BASEDIR)/stylesheets
	$(Q)sed -i 's|../stylesheet|stylesheet|' $(BASEDIR)/index.html

	$(Q)if [ ! -e $(BASEDIR)/images ]; then \
      mkdir -p $(BASEDIR)/images;          \
   fi;
	$(Q)cp images/*.{png,ico} $(BASEDIR)/images

	$(Q)cd $(BASEDIR)/; sed -e "s@../images@images@g"           \
                           -i *.html

	@echo "Running Tidy and obfuscate.sh on chunked XHTML..."
	$(Q)for filename in `find $(BASEDIR) -name "*.html"`; do       \
      tidy -config tidy.conf $$filename;                          \
      true;                                                       \
      bash obfuscate.sh $$filename;                               \
      sed -i -e "1,20s@text/html@application/xhtml+xml@g" $$filename; \
   done;

pdf: validate
	@echo "Generating profiled XML for PDF..."
	$(Q)xsltproc --nonet \
						--stringparam profile.condition pdf \
						--output $(RENDERTMP)/glfs-pdf.xml  \
						stylesheets/lfs-xsl/profile.xsl     \
						$(RENDERTMP)/glfs-full.xml

	@echo "Generating FO file..."
	$(Q)xsltproc --nonet										\
					--stringparam rootid "$(ROOT_ID)"	\
					--output $(RENDERTMP)/glfs-pdf.fo	\
					stylesheets/glfs-pdf.xsl					\
					$(RENDERTMP)/glfs-pdf.xml

	$(Q)sed -i -e 's/span="inherit"/span="all"/' $(RENDERTMP)/glfs-pdf.fo
	$(Q)bash pdf-fixups.sh $(RENDERTMP)/glfs-pdf.fo

	@echo "Generating PDF file..."
	$(Q)mkdir -p $(RENDERTMP)/images
	$(Q)cp images/*.png $(RENDERTMP)/images

	$(Q)mkdir -p $(BASEDIR)

	$(Q)fop -q $(RENDERTMP)/glfs-pdf.fo $(BASEDIR)/$(PDF_OUTPUT) 2>fop.log
	@echo "$(BASEDIR)/$(PDF_OUTPUT) created"
	@echo "fop.log created"
	$(Q)rm fop.log
	@echo "fop.log destroyed"

nochunks: $(BASEDIR)/$(NOCHUNKS_OUTPUT)
$(BASEDIR)/$(NOCHUNKS_OUTPUT): $(RENDERTMP)/$(GLFSHTML) version
	@echo "Generating non-chunked XHTML file..."
	$(Q)xsltproc --nonet                                \
                --stringparam rootid "$(ROOT_ID)"      \
                --output $(BASEDIR)/$(NOCHUNKS_OUTPUT) \
                stylesheets/glfs-nochunks.xsl          \
                $(RENDERTMP)/$(GLFSHTML)

	@echo "Running Tidy and obfuscate.sh on non-chunked XHTML..."
	$(Q)tidy -config tidy.conf $(BASEDIR)/$(NOCHUNKS_OUTPUT) || true
	$(Q)bash obfuscate.sh $(BASEDIR)/$(NOCHUNKS_OUTPUT)
	$(Q)sed -i -e "1,20s@text/html@application/xhtml+xml@g" $(BASEDIR)/$(NOCHUNKS_OUTPUT)

tmpdir: $(RENDERTMP)
$(RENDERTMP):
	@echo "Creating $(RENDERTMP)"
	$(Q)[ -d $(RENDERTMP) ] || mkdir -p $(RENDERTMP)

clean:
	@echo "Cleaning $(RENDERTMP)"
	$(Q)rm -f $(RENDERTMP)/glfs*

validate: $(RENDERTMP)/$(GLFSFULL)
$(RENDERTMP)/$(GLFSFULL): general.ent packages.ent $(ALLXML) $(ALLXSL) version
	$(Q)[ -d $(RENDERTMP) ] || mkdir -p $(RENDERTMP)

	@echo "Adjusting for revision $(REV)..."
	$(Q)xsltproc --nonet                               \
                --xinclude                            \
                --output $(RENDERTMP)/$(GLFSHTML2)    \
                --stringparam profile.revision $(REV) \
                stylesheets/lfs-xsl/profile.xsl       \
                index.xml

	@echo "Validating the book..."
	$(Q)xmllint --nonet                             \
               --noent                             \
               --postvalid                         \
               --output $(RENDERTMP)/$(GLFSFULL)   \
               $(RENDERTMP)/$(GLFSHTML2)

profile-html: $(RENDERTMP)/$(GLFSHTML)
$(RENDERTMP)/$(GLFSHTML): $(RENDERTMP)/$(GLFSFULL) version
	@echo "Generating profiled XML for XHTML..."
	$(Q)xsltproc --nonet                              \
                --stringparam profile.condition html \
                --output $(RENDERTMP)/$(GLFSHTML)    \
                stylesheets/lfs-xsl/profile.xsl      \
                $(RENDERTMP)/$(GLFSFULL)

glfs-patch-list: glfs-patches.sh
	@echo "Generating glfs patch list..."
	$(Q)awk '{if ($$1 == "copy") {sub(/.*\//, "", $$2); print $$2}}' \
	  glfs-patches.sh > glfs-patch-list

glfs-patches.sh: $(RENDERTMP)/$(GLFSFULL) version
	@echo "Generating glfs patch script..."
	$(Q)xsltproc --nonet                     \
                --output glfs-patches.sh    \
                stylesheets/patcheslist.xsl \
                $(RENDERTMP)/$(GLFSFULL)

wget-list: $(BASEDIR)/wget-list
$(BASEDIR)/wget-list: $(RENDERTMP)/$(GLFSFULL) version
	@echo "Generating wget list for $(REV) at $(BASEDIR)/wget-list ..."
	$(Q)mkdir -p $(BASEDIR)
	$(Q)xsltproc --nonet                       \
                --output $(BASEDIR)/wget-list \
                stylesheets/wget-list.xsl     \
                $(RENDERTMP)/$(GLFSFULL)

test-links: $(BASEDIR)/test-links
$(BASEDIR)/test-links: $(RENDERTMP)/$(GLFSFULL) version
	@echo "Generating test-links file..."
	$(Q)mkdir -p $(BASEDIR)
	$(Q)xsltproc --nonet                        \
                --stringparam list_mode full   \
                --output $(BASEDIR)/test-links \
                stylesheets/wget-list.xsl      \
                $(RENDERTMP)/$(GLFSFULL)

	@echo "Checking URLs, first pass..."
	$(Q)rm -f $(BASEDIR)/{good,bad,true_bad}_urls
	$(Q)for URL in `cat $(BASEDIR)/test-links`; do                     \
         wget --spider --tries=2 --timeout=60 $$URL >>/dev/null 2>&1; \
         if test $$? -ne 0 ; then                                     \
            echo $$URL >> $(BASEDIR)/bad_urls ;                       \
         else                                                         \
            echo $$URL >> $(BASEDIR)/good_urls 2>&1;                  \
         fi;                                                          \
   done

	@echo "Checking URLs, second pass..."
	$(Q)for URL2 in `cat $(BASEDIR)/bad_urls`; do                       \
         wget --spider --tries=2 --timeout=60 $$URL2 >>/dev/null 2>&1; \
         if test $$? -ne 0 ; then                                      \
           echo $$URL2 >> $(BASEDIR)/true_bad_urls ;                   \
         else                                                          \
           echo $$URL2 >> $(BASEDIR)/good_urls 2>&1;                   \
         fi; \
   done

bootscripts:
	@VERSION=`grep "bootscripts-version " general.ent | cut -d\" -f2`; \
   BOOTSCRIPTS="glfs-bootscripts-$$VERSION";                          \
   if [ ! -e $$BOOTSCRIPTS.tar.xz ]; then                             \
     rm -rf $(RENDERTMP)/$$BOOTSCRIPTS;                               \
     mkdir $(RENDERTMP)/$$BOOTSCRIPTS;                                \
     cp -a ../bootscripts/* $(RENDERTMP)/$$BOOTSCRIPTS;               \
     rm -rf ../bootscripts/archive;                                   \
     tar  -cJhf $$BOOTSCRIPTS.tar.xz -C $(RENDERTMP) $$BOOTSCRIPTS;   \
   fi

systemd-units:
	@VERSION=`grep "systemd-units-version " general.ent | cut -d\" -f2`; \
   UNITS="glfs-systemd-units-$$VERSION";                                \
   if [ ! -e $$UNITS.tar.xz ]; then                                     \
     rm -rf $(RENDERTMP)/$$UNITS;                                       \
     mkdir $(RENDERTMP)/$$UNITS;                                        \
     cp -a ../systemd-units/* $(RENDERTMP)/$$UNITS;                     \
     tar -cJhf $$UNITS.tar.xz -C $(RENDERTMP) $$UNITS;                  \
   fi

test-options:
	$(Q)xsltproc --xinclude --nonet stylesheets/test-options.xsl index.xml

dump-commands: $(DUMPDIR)
$(DUMPDIR): $(RENDERTMP)/$(GLFSFULL) version
	@echo "Dumping book commands..."
	$(Q)xsltproc --output $(DUMPDIR)/          \
                stylesheets/dump-commands.xsl \
                $(RENDERTMP)/$(GLFSFULL)
	$(Q)touch $(DUMPDIR)

.PHONY: glfs all world html nochunks tmpdir clean             \
   validate profile-html glfs-patch-list wget-list test-links \
   dump-commands  bootscripts systemd-units version test-options

version:
	$(Q)./git-version.sh $(REV)
