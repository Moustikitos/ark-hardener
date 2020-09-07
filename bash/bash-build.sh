#!/bin/bash

PYTHON_VERSIONS='3.5.8 3.6.12 3.7.9 3.8.5'
IS_PY64="$(python -c 'import sys;print(sys.maxsize==2**64//2-1)')"

cd ${HOME}/ark-hardener

for VERSION in $PYTHON_VERSIONS; do
    rm pyrex.so
    pyenv global ${VERSION}

    MINOR="${VERSION[@]: 2:1}"
    if [ $IS_PY64 = 'True' ]; then
        MACHINE="x64"
    else
        MACHINE="x32"
    fi

    python -m nuitka --module --follow-imports --include-package=pyrex pyrex
    mv pyrex.so bin/pyrex.${MACHINE}.cpython-3${MINOR}.so
done
