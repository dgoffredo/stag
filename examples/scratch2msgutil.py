"""Provide codecs for types defined in (scratch2msg).

"""
import scratch2msg as types
import _scratch2msg as gencodeutil
import typing


def to_jsonable(obj: typing.Any) -> typing.Any:
    """Return a composition of python objects (such as 'dict', 'list' and
    'str') based on the specified 'obj' such that the result is suitable for
    serialization to JSON by the 'json' module.
    """
    return gencodeutil.to_jsonable(obj, _name_mappings)


def from_jsonable(return_type: typing.Any, obj: typing.Any) -> typing.Any:
    """Return an instance of the specified 'return_type' that has been
    constructed based on the specified 'obj', which is a composition of python
    objects as would result from JSON deserialization by the 'json' module.
    """
    return gencodeutil.from_jsonable(return_type, obj, _name_mappings,
                                     _class_by_name)


_name_mappings = {
    types.SomeChoice:
    gencodeutil.NameMapping({
        "foo": "foo",
        "bar": "bar"
    }),
    types.Color:
    gencodeutil.NameMapping({
        "RED": "RED",
        "BLUE": "BLUE",
        "GREEN": "GREEN"
    })
}

_class_by_name = {klass.__name__: klass for klass in _name_mappings}

# This is the version string identifying the version of stag that generated
# this code. Search through the code generator's git repository history for
# this string to find the commit of the contemporary code generator.
_code_generator_version = "The fishy big-boned clinical treasure throws the jaded slimey wild gavel while the ice throws the angry fuzzy ecumenical manager."
