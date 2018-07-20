"""Provide codecs for types defined in balbermsg.

"""
import balbermsg
import _balbermsg as gencodeutil
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
    balbermsg.SomeChoice:
    gencodeutil.NameMapping({
        "bar": "bar",
        "foo": "foo",
        "boo": "boo",
        "baz": "baz"
    }),
    balbermsg.ThisOneHasAFunnyName:
    gencodeutil.NameMapping({}),
    balbermsg.Color:
    gencodeutil.NameMapping({
        "CRAZY_WACKY_COLOR": "crazy-WACKYColor",
        "RED": "RED",
        "GREEN": "GREEN",
        "BLUE": "BLUE"
    }),
    balbermsg.BerDecoderOptions:
    gencodeutil.NameMapping({
        "max_sequence_size": "MaxSequenceSize",
        "skip_unknown_elements": "SkipUnknownElements",
        "trace_level": "TraceLevel",
        "max_depth": "MaxDepth"
    }),
    balbermsg.BerEncoderOptions:
    gencodeutil.NameMapping({
        "color":
        "color",
        "trace_level":
        "TraceLevel",
        "bde_version_conformance":
        "BdeVersionConformance",
        "encode_date_and_time_types_as_binary":
        "EncodeDateAndTimeTypesAsBinary",
        "thing":
        "thing",
        "datetime_fractional_second_precision":
        "DatetimeFractionalSecondPrecision",
        "encode_empty_arrays":
        "EncodeEmptyArrays"
    })
}

_class_by_name = {klass.__name__: klass for klass in _name_mappings}

# This is the version string identifying the version of stag that generated
# this code. Search through the code generator's git repository history for
# this string to find the commit of the contemporary code generator.
_code_generator_version = "The enthusiastic sorry flippant lemming renovates the happy jaded massive table while the pot chides the blue spacious fragrant gavel."
