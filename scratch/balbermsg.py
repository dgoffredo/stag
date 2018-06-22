"""Provide typed attribute classes.

This module provides typed attribute classes generated from a schema.

Instances of the types defined in this module are immutable, and may be
converted to and from JSON-compatible objects using the similarly-named
utilities module that is dual to this module.
"""
from datetime import datetime
import enum
import gencodeutil
import typing


class Color(enum.Enum):
    RED = 0
    GREEN = 1
    BLUE = 2
    CRAZY_WACKY_COLOR = 3


class BerDecoderOptions(gencodeutil.Sequence):
    """BER decoding options
    """
    # maximum recursion depth
    max_depth: typing.Optional[int] = 32
    # Option to skip unknown elements
    skip_unknown_elements: typing.Optional[bool] = True
    # trace (verbosity) level
    trace_level: typing.Optional[int] = 0
    # maximum sequence size
    max_sequence_size: typing.Optional[int] = 8388608

    def __init__(self,
                 *,
                 max_depth: typing.Optional[int] = 32,
                 skip_unknown_elements: typing.Optional[bool] = True,
                 trace_level: typing.Optional[int] = 0,
                 max_sequence_size: typing.Optional[int] = 8388608) -> None:
        gencodeutil.Sequence.__init__(**locals())


class BerEncoderOptions(gencodeutil.Sequence):
    """BER encoding options
    """
    # trace (verbosity) level
    trace_level: typing.Optional[int] = 0
    # The largest BDE version that can be assumed of the corresponding decoder
    # for the encoded message, expressed as 10000*majorVersion +
    # 100*minorVersion + patchVersion (e.g. 1.5.0 is expressed as 10500).
    #
    # Ideally, the BER encoder should be permitted to generate any BER that
    # conforms to X.690 (Basic Encoding Rules) and X.694 (mapping of XSD to
    # ASN.1). In practice, however, certain unimplemented features and
    # missunderstandings of these standards have resulted in a decoder that
    # cannot accept the full range of legal inputs. Even when the encoder and
    # decoder are both upgraded to a richer subset of BER, the program
    # receiving the encoded values may not have been recompiled with the latest
    # version and, thus restricting the encoder to emit BER that can be
    # understood by the decoder at the other end of the wire. If it is that the
    # receiver has a more modern decoder, set this variable to a larger value
    # to allow the encoder to produce BER that is richer and more standards
    # conformant. The default should be increased only when old copies of the
    # decoder are completely out of circulation.
    bde_version_conformance: int = 10500
    # This option allows users to control if empty arrays are encoded. By
    # default empty arrays are encoded as not encoding empty arrays is
    # non-compliant with the BER encoding specification.
    encode_empty_arrays: bool = True
    # This option allows users to control if date and time types are encoded as
    # binary integers. By default these types are encoded as strings in the ISO
    # 8601 format.
    encode_date_and_time_types_as_binary: bool = False
    # This option controls the number of decimal places used for seconds when
    # encoding 'Datetime' and 'DatetimeTz'.
    datetime_fractional_second_precision: typing.Optional[int] = 3
    color: "Color" = Color.CRAZY_WACKY_COLOR
    thing: "SomeChoice"

    def __init__(
            self,
            *,
            trace_level: typing.Optional[int] = 0,
            bde_version_conformance: int = 10500,
            encode_empty_arrays: bool = True,
            encode_date_and_time_types_as_binary: bool = False,
            datetime_fractional_second_precision: typing.Optional[int] = 3,
            color: "Color" = Color.CRAZY_WACKY_COLOR,
            thing: "SomeChoice") -> None:
        gencodeutil.Sequence.__init__(**locals())


class SomeChoice(gencodeutil.Choice):
    foo: float
    bar: datetime

    def __init__(self, **kwarg: typing.Union[float, datetime]) -> None:
        gencodeutil.Choice.__init__(self, **kwarg)
