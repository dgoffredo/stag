#!/bin/bash

# Pass the name of the library whose types to generate, e.g. "balber".
library="${1:-balber}"

# Pop that library name off of the arguments, if it was specified at all. This
# is so the remaining arguments can be forwarded to the code generator.
shift

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
REPO=$(readlink -f $(dirname $BASH_SOURCE)/../)

# Go into the scratch/ directory and run stag on the schema. 
run_checked cd $REPO/scratch
run_checked racket $REPO/src/stag/stag.rkt "$@" $library.xsd

# Stag will have produced these two python modules.
FILES="${library}msg.py ${library}msgutil.py"

# Format the python code in place.
for module in $FILES; do
    run_checked yapf -i $module
done

# Run python's type checker on the generated code.
for module in $FILES; do
    run_checked mypy --strict $module
done

# Run the generated modules in a python interpreter.
for module in $FILES; do
    run_checked python3.6 $module
done
