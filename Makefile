# vim:ts=3
# Makefile for GLFS Book generation.
# By Tushar Teredesai <tushar@linuxfromscratch.org>
# 2004-01-31
# Edited by Zeckma    <zeckma.tech@gmail.com>
# 2025-01-12

# When rendering for the stable release from the stable branch, invoke
# STAB=release to make.

-include local.mk

# Adjust these to suit your installation, or include the variables
# you wish to change in local.mk, which must be created manually.
REV         ?= systemd
STAB        ?= development
WORKFLOW    ?= n
THEME_PATH  ?= stylesheets/lfs-xsl
THEME       ?= dynamic
RENDERTMP   := $(shell mktemp -d)
HTML_ROOT   ?= $(HOME)/public_html
DUMP_ROOT   ?= $(HOME)
CHUNK_QUIET ?= 1
SHELL        = /bin/bash

ALLXML := $(shell find . -mindepth 1 -name '*.xml' ! -path '$(RENDERTMP)/*')
ALLXSL := $(shell find . -mindepth 1 -name '*.xsl' ! -path '$(RENDERTMP)/*')

ifdef V
  Q =
else
  Q = @
endif

ifneq ($(REV), systemd)
  ifneq ($(REV), openrc)
    ifneq ($(REV), sysv)
      $(error REV must be 'systemd' (default), 'openrc', or 'sysv' (not maintained))
    endif
  endif
endif

# Used in the book, does not actually change if the book will render for the
# stable git hash, just changes if text for stable release is rendered or not.
ifneq ($(STAB), development)
  ifneq ($(STAB), release)
    $(error STAB must be 'development' (default) or 'release')
  endif
endif

ifeq ($(REV), systemd)
  BASEDIR         ?= $(HTML_ROOT)/glfs
  DUMPDIR         ?= $(DUMP_ROOT)/glfs-commands
  GLFSHTML        ?= glfs-html.xml
  GLFSHTML2       ?= glfs-html2.xml
  GLFSFULL        ?= glfs-full.xml
endif
ifeq ($(REV), openrc)
  BASEDIR         ?= $(HTML_ROOT)/glfs-openrc
  DUMPDIR         ?= $(DUMP_ROOT)/glfs-openrc-commands
  GLFSHTML        ?= glfs-openrc-html.xml
  GLFSHTML2       ?= glfs-openrc-html2.xml
  GLFSFULL        ?= glfs-openrc-full.xml
endif
ifeq ($(REV), sysv)
  BASEDIR         ?= $(HTML_ROOT)/glfs-sysv
  DUMPDIR         ?= $(DUMP_ROOT)/glfs-sysv-commands
  GLFSHTML        ?= glfs-sysv-html.xml
  GLFSHTML2       ?= glfs-sysv-html2.xml
  GLFSFULL        ?= glfs-sysv-full.xml
endif

glfs: html post-render

help:
	@echo ""
	@echo "make <parameters> <targets>"
	@echo ""
	@echo "Parameters:"
	@echo ""
	@echo "  REV=<rev>            Build variation of book"
	@echo "                       Valid values for REV are:"
	@echo "                       * systemd - Build book for Systemd"
	@echo "                       * openrc  - Build book for OpenRC"
	@echo "                       * sysv    - Build book for SysVinit"
	@echo "                       Defaults to 'systemd'"
	@echo ""
	@echo "  BASEDIR=<dir>        Put the output in directory <dir>."
	@echo "                       Defaults to"
	@echo "                       '$(HTML_ROOT)/glfs' if REV=systemd (or unset),"
	@echo "                       '$(HTML_ROOT)/glfs-openrc' if REV=openrc,"
	@echo "                       or to"
	@echo "                       '$(HTML_ROOT)/glfs-sysv' if REV=sysv"
	@echo ""
	@echo "  V=<val>              If <val> is a non-empty value, all"
	@echo "                       steps to produce the output is shown."
	@echo "                       Default is unset."
	@echo ""
	@echo "  THEME_PATH=<PATH>    Sets the path of themes (CSS files)."
	@echo "                       stylesheets/lfs-xsl' is the default."
	@echo ""
	@echo "  THEME=<theme>        Sets the theme of the book, ie."
	@echo "                       light/dark/dynamic."
	@echo "                       'dynamic' is the default."
	@echo ""
	@echo "Targets:"
	@echo "  help                 Show this help text."
	@echo ""
	@echo "  glfs                 Builds targets 'html' and 'wget-list'."
	@echo ""
	@echo "  html                 Builds the HTML pages of the book."
	@echo ""
	@echo "  wget-list            Produces a list of all packages to download."
	@echo "                       Output is BASEDIR/download/wget-list"
	@echo ""
	@echo "  validate             Runs validation checks on the XML files."
	@echo ""
	@echo "  test-links           Runs validation checks on URLs in the book."
	@echo "                       Produces a file named BASEDIR/bad_urls containing"
	@echo "                       URLS which are invalid and a BASEDIR/good_urls"
	@echo "                       containing all valid URLs."
	@echo ""

all: glfs
post-render: downloads wget-list assets legacy-html
world: all dump-commands test-links

html: $(BASEDIR)/index.html
$(BASEDIR)/index.html: $(RENDERTMP)/$(GLFSHTML) version
	@echo "Generating chunked XHTML files..."
	$(Q)xsltproc --nonet                                    \
					--stringparam chunk.quietly $(CHUNK_QUIET) \
					--stringparam base.dir $(BASEDIR)/         \
					stylesheets/glfs-chunked.xsl               \
					$(RENDERTMP)/$(GLFSHTML)
	
	@echo "Running Tidy and obfuscate.sh on chunked XHTML..."
	$(Q)for filename in `find $(BASEDIR) -name "*.html"`; do       \
      tidy -config tidy.conf $$filename;                          \
      true;                                                       \
      bash obfuscate.sh $$filename;                               \
      sed -i -e "1,20s@text/html@application/xhtml+xml@g" $$filename; \
   done;

validate: $(RENDERTMP)/$(GLFSFULL)
$(RENDERTMP)/$(GLFSFULL): general.ent packages.ent $(ALLXML) $(ALLXSL) version
	$(Q)mkdir -p $(RENDERTMP)
	
	@echo "Rendering the book for $(REV)..."
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

downloads: $(BASEDIR)/download
$(BASEDIR)/download: html
	@echo "Copying downloadable content to $(BASEDIR)/download..."
	$(Q)mkdir -p $(BASEDIR)/download
	$(Q)rm -rf $(BASEDIR)/download/*
	$(Q)cp -R download/* $(BASEDIR)/download
	$(Q)rm -rf $(BASEDIR)/patches
	$(Q)ln -snf download $(BASEDIR)/patches

wget-list: $(BASEDIR)/download/wget-list
$(BASEDIR)/download/wget-list: $(RENDERTMP)/$(GLFSFULL) version html downloads
	@echo "Generating $(REV) wget-list to $(BASEDIR)/download..."
	$(Q)xsltproc --nonet                                \
                --output $(BASEDIR)/download/wget-list \
                stylesheets/wget-list.xsl              \
                $(RENDERTMP)/$(GLFSFULL)

legacy-html: $(BASEDIR)/archive
$(BASEDIR)/archive: html
	@echo "Copying legacy HTML..."
	$(Q)mkdir -p $(BASEDIR)/archive
	$(Q)cp -R archive/*.html $(BASEDIR)/archive

assets: $(BASEDIR)/stylesheets $(BASEDIR)/images
$(BASEDIR)/stylesheets: html
	@echo "Copying CSS..."
	$(Q)mkdir -p $(BASEDIR)/stylesheets
	$(Q)cp $(THEME_PATH)/$(THEME).lfs.css $(BASEDIR)/stylesheets/lfs.css
	$(Q)cp stylesheets/lfs-xsl/lfs-print.css $(BASEDIR)/stylesheets
	$(Q)sed -i 's|../stylesheet|stylesheet|' $(BASEDIR)/index.html
$(BASEDIR)/images: html
	@echo "Copying images..."
	$(Q)mkdir -p $(BASEDIR)/images
	$(Q)cp -R images/* $(BASEDIR)/images
	$(Q)cd $(BASEDIR)/; sed -e "s@../images@images@g" -i *.html

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

test-options:
	$(Q)xsltproc --xinclude --nonet stylesheets/test-options.xsl index.xml

dump-commands: $(DUMPDIR)
$(DUMPDIR): $(RENDERTMP)/$(GLFSFULL) version
	@echo "Dumping book commands at $(DUMPDIR)..."
	$(Q)xsltproc --output $(DUMPDIR)/          \
                stylesheets/dump-commands.xsl \
                $(RENDERTMP)/$(GLFSFULL)
	$(Q)touch $(DUMPDIR)

.PHONY: glfs post-render all world html validate profile-html downloads \
   wget-list assets test-links dump-commands version test-options

version:
	$(Q)REV=$(REV) STAB=$(STAB) WORKFLOW=$(WORKFLOW) ./git-version.sh
