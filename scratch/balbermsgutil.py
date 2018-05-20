
"""Provide codecs for types defined in balbermsg.
"""
import balbermsg
import gencodeutil


def to_json(obj):
    return gencodeutil.to_json(obj, _name_mappings)


def from_json(return_type, obj):
    return gencodeutil.from_json(return_type, obj, _name_mappings)


_name_mappings = {balbermsg.BerEncoderOptions: gencodeutil.NameMapping({"bde_version_conformance": "BdeVersionConformance", "trace_level": "TraceLevel", "datetime_fractional_second_precision": "DatetimeFractionalSecondPrecision", "encode_empty_arrays": "EncodeEmptyArrays", "thing": "thing", "color": "color", "encode_date_and_time_types_as_binary": "EncodeDateAndTimeTypesAsBinary"}), balbermsg.Color: gencodeutil.NameMapping({"BLUE": "BLUE", "GREEN": "GREEN", "RED": "RED", "CRAZY_WACKY_COLOR": "crazy-WACKYColor"}), balbermsg.BerDecoderOptions: gencodeutil.NameMapping({"max_depth": "MaxDepth", "trace_level": "TraceLevel", "skip_unknown_elements": "SkipUnknownElements", "max_sequence_size": "MaxSequenceSize"}), balbermsg.SomeChoice: gencodeutil.NameMapping({"bar": "bar", "foo": "foo"})}
