"""Provide typed attribute classes.

This module provides typed attribute classes generated from a schema.

Instances of the types defined in this module are immutable, and may be
converted to and from JSON-compatible objects using the similarly-named
utilities module that is dual to this module.
"""
import _scratch2msg as gencodeutil
import enum
import typing


class Color(enum.Enum):
    RED = 0
    GREEN = 1
    BLUE = 2


class SomeChoice(gencodeutil.Choice):
    foo: float
    bar: "Color"

    def __init__(self, **kwarg: typing.Union[float, "Color"]) -> None:
        gencodeutil.Choice.__init__(self, **kwarg)


# This is the version string identifying the version of stag that generated
# this code. Search through the code generator's git repository history for
# this string to find the commit of the contemporary code generator.
_code_generator_version = "The spiritual fishy flaky dinosaur entrances the funny spiritual agnostic coffee while the cleaver observes the jaded chipper conservative napkin."
