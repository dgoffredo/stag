"""Provide codecs for types defined in mysvcmsg.
"""

import mysvcmsg
import gencodeutil


def to_jsonable(obj):
    return gencodeutil.to_jsonable(obj, _name_mappings)


def from_jsonable(return_type, obj):
    return gencodeutil.from_jsonable(return_type, obj, _name_mappings)


_name_mappings = {
    mysvcmsg.BerEncoderOptions:
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
    mysvcmsg.Color:
    gencodeutil.NameMapping({
        "BLUE": "BLUE",
        "GREEN": "GREEN",
        "RED": "RED",
        "CRAZY_WACKY_COLOR": "crazy-WACKYColor"
    }),
    mysvcmsg.BerDecoderOptions:
    gencodeutil.NameMapping({
        "max_depth": "MaxDepth",
        "trace_level": "TraceLevel",
        "skip_unknown_elements": "SkipUnknownElements",
        "max_sequence_size": "MaxSequenceSize"
    }),
    mysvcmsg.SomeChoice:
    gencodeutil.NameMapping({
        "bar": "bar",
        "foo": "foo"
    })
}
