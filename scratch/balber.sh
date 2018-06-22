#!/bin/bash

run_checked() {
    # Execute the arguments to this function as a command, and if it returns a
    # nonzero status code, print a diagnostic to standard error and exit the
    # shell using the same status code.
    "$@"
    rcode=$?
    if [ $rcode -ne 0 ]; then
        >&2 echo "" # for the newline
        >&2 echo "Status $rcode returned by command: $@"
        exit $rcode
    fi
}

# Deduce where the stag root is based on where this script is assumed to be.
REPO=$(dirname $BASH_SOURCE)/../

# Go into the scratch/ directory and run stag on the schema. 
run_checked cd $REPO/scratch
run_checked racket $REPO/src/stag/stag.rkt balber.xsd

# Stag will have produced these two python modules.
FILES="balbermsg.py balbermsgutil.py"

# Format the python code in place.
run_checked yapf -i $FILES

# Run python's type checker on the generated code.
run_checked mypy --strict $FILES

# Run the generated modules in a python interpreter.
for module in $FILES; do
    run_checked python3.6 $module
done
