#!/usr/bin/env bash
#
#  Copyright (c) 2015 unfoldingWord
#  http://creativecommons.org/licenses/MIT/
#  See LICENSE file for details.
#
#  Contributors:
#  dboerschlein
#  Jesse Griffin <jesse@distantshores.org>
#  Caleb Maclennan <caleb@alerque.com>

## GET SET UP ##

# Fail if _any_ command goes wrong
set -e

help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "    -c       Override checking level (1, 2 or 3)"
    echo "    -d       Show debug messages while running script"
    echo "    -l LANG  Add language(s) to process"
    echo "    -o DIR   Add output directory for final PDF"
    echo "    -r LOC   Send build report to directory(s) or email address(s)"
    echo "    -t TAG   Add a tag to the output filename"
    echo "    -v VER   Override the version field in the output"
    echo "    -h       Show this help"
    echo "Notes:"
    echo "    Option flags whose values are marked '(s)' may be specified multiple times"
}

# Process command line options
while getopts c:del:m:o:r:t:v:h opt; do
    case $opt in
        c) checking=$OPTARG;;
        d) debug=true;;
        l) langs=("${langs[@]}" "$OPTARG");;
        o) outdir=$OPTARG;;
        r) reportto=("${reportto[@]}" "$OPTARG");;
        t) tag=$OPTARG;;
        v) version=$OPTARG;;
        h) help && exit 0;;
        ?) help && exit 1;;
    esac
done

# Setup variable defaults in case flags were not set
: ${checking=}
: ${debug=false}
: ${edit=false}
: ${langs[0]=${LANG%_*}}
: ${outdir=$(pwd)}
: ${reportto[0]=}
: ${tag=}
: ${version=}

# Note out base location and create a temporary workspace
BASEDIR=$(cd $(dirname "$0")/../ && pwd)
BUILDDIR=$(mktemp -d --tmpdir "ta_build_pdf.XXXXXX")
LOG="$BUILDDIR/shell.log"
TEMPLATE="$BASEDIR/general_tools/pandoc_pdf_template.tex"

# Output info about every command (and don't clean up on exit) if in debug mode
$debug && set -x
$debug || trap 'cd "$BASEDIR"; rm -rf "$BUILDDIR"' EXIT SIGHUP SIGTERM

## PROCESS LANGUAGES AND BUILD PDFS ##

pushd "$BUILDDIR"
ln -sf "$BASEDIR/ta"

for lang in "${langs[@]}"; do
    # Get the version for this language (if not forced from an option flag)
#    LANGVER=${version:-$("$BASEDIR"/uw/get_ver.py $lang)}
    LANGVER=1

    # Pick a filename based on all the parts we have
    BASENAME="ta-${lang}-v${LANGVER/./_}${tag:+-$tag}"

    # Run python (json_to_html.py) to generate the html file to use in the PDF
    ./ta/export.py -l $lang ${checking:+-c $checking} -o "$BASENAME.html"

    LOGO="https://unfoldingWord.org/assets/img/icon-ta.png"
    TITLE="translationAcademy"
    DATE=`date +"%Y-%m-%d"`

    curl -o logo.png "$LOGO"

    # Create PDF
    pandoc \
        -S \
        --latex-engine="xelatex" \
        --template="$TEMPLATE" \
        --toc \
        --toc-depth=4 \
        -V documentclass="scrartcl" \
        -V classoption="oneside" \
        -V geometry='hmargin=2cm' \
        -V geometry='vmargin=3cm' \
        -V logo="logo.png" \
        -V title="$TITLE" \
        -V date="$DATE" \
        -V mainfont="Noto Serif" \
        -V sansfont="Noto Sans" \
        -o "${BASENAME}.pdf" "${BASENAME}.html"

        if [ $BUILDDIR != $outdir ]; then
            cp "${BASENAME}.pdf" "$outdir/${BASENAME}.pdf"
        fi

        echo "GENERATED FILE: $outdir/${BASENAME}.pdf"
done
