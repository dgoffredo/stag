#!python3.6

"""Blah blah blah blah.

Blah blah, blah blah blah, blah blah... blah.
"""

from namedunion import NamedUnion
from typing import NamedTuple, List
from enum import Enum


class Color(Enum):
    RED = 0
    GREEN = 1
    BLUE = 2


class Laces(NamedTuple):
    length_cm : float
    color : Color


class Velcro(NamedTuple):
    num_strips : int


class Fastening(NamedUnion):
    laces : Laces
    velcro: Velcro


class Shoe(NamedTuple):
    color : Color
    size_us : float
    fastening : Fastening
    style : str = 'loafer' # default
    tags : List[str] = []


converse = Shoe(color=Color.GREEN, 
                size_us=12, 
                fastening=Fastening(laces=Laces(length_cm=30, color=Color.RED)),
                style='low top')
