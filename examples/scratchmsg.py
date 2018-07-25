"""Provide typed attribute classes.

This module provides typed attribute classes generated from a schema.

Instances of the types defined in this module are mutable, and may be converted
to and from JSON-compatible objects using the similarly-named utilities module
that is dual to this module.
"""
import _scratchmsg as gencodeutil
import enum
import typing


class Color(enum.Enum):
    RED = 0
    GREEN = 1
    BLUE = 2


class SomeChoice(gencodeutil.Choice):
    foo: float
    bar: str

    def __init__(self, **kwarg: typing.Union[float, str]) -> None:
        gencodeutil.Choice.__init__(self, **kwarg)


# This is the version string identifying the version of stag that generated
# this code. Search through the code generator's git repository history for
# this string to find the commit of the contemporary code generator.
_code_generator_version = "The red soaked funny asphalt educates the sorry marginal long-winded apple while the beaver pokes the fantastic short-sighted happy battery."
