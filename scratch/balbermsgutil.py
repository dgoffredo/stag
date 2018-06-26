"""Provide codecs for types defined in balbermsg.

"""
import balbermsg
import gencodeutil
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
    return gencodeutil.from_jsonable(return_type, obj, _name_mappings)


_name_mappings = {
    balbermsg.BerEncoderOptions:
    gencodeutil.NameMapping({
        "bde_version_conformance":
        "BdeVersionConformance",
        "trace_level":
        "TraceLevel",
        "datetime_fractional_second_precision":
        "DatetimeFractionalSecondPrecision",
        "encode_empty_arrays":
        "EncodeEmptyArrays",
        "thing":
        "thing",
        "color":
        "color",
        "encode_date_and_time_types_as_binary":
        "EncodeDateAndTimeTypesAsBinary"
    }),
    balbermsg.Color:
    gencodeutil.NameMapping({
        "BLUE": "BLUE",
        "GREEN": "GREEN",
        "RED": "RED",
        "CRAZY_WACKY_COLOR": "crazy-WACKYColor"
    }),
    balbermsg.BerDecoderOptions:
    gencodeutil.NameMapping({
        "max_depth": "MaxDepth",
        "trace_level": "TraceLevel",
        "skip_unknown_elements": "SkipUnknownElements",
        "max_sequence_size": "MaxSequenceSize"
    }),
    balbermsg.SomeChoice:
    gencodeutil.NameMapping({
        "bar": "bar",
        "foo": "foo"
    })
}

# This is the version string identifying the version of stag that generated
# this code. Search through the code generator's git repository history for
# this string to find the commit of the contemporary code generator.
_code_generator_version = "The tiny sunken funny constable overrides the tiny agnostic discounted lanyard while the gravel smothers the rotund fantastic white rum."
