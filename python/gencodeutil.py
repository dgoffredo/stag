'''serialization utilities used in generated classes

Provide base classes, utility types, and conversion routines for generated
classes.
'''

from enum import Enum
from typing import Any, Dict, Iterator, List, Mapping, Optional, Tuple, Type, Union

import decimal
import datetime
import re


class Sequence:
    """Base class for plain attribute types. Provides iteration,
    subscripting, and an initializer that just assigns attributes.
    """

    def __init__(self, **kwargs: Any) -> None:
        for attr, value in kwargs.items():
            setattr(self, attr, value)

    def __iter__(self) -> Iterator[Any]:
        """Iterate over the attribute values in order."""
        for attr in self.__annotations__:
            yield getattr(self, attr)

    def __getitem__(self, index: int) -> Any:
        """Get the index'th (zero-based) attribute value."""
        attr = list(self.__annotations__.keys())[index]
        return getattr(self, attr)


def _attr_list(obj: Any) -> List[str]:
    """Return a list of obj's annotated attribute names."""
    return list(obj.__annotations__.keys())


class Choice:
    """Base class for a single named selection, possibly among many.
    Provides a keyword-only constructor and __setattr__ that restrict
    attributes to those annotated in the derived class and that keep
    track of which selection is made in the read-only '_selection' property.
    """
    _selection: str

    def __init__(self, **kwarg: Any) -> None:
        if len(kwarg) != 1:
            raise ValueError(f'Choice initializer received {len(kwarg)} '
                             f'arguments when it supports only one.')

        (attr, value), = kwarg.items()
        if attr not in self.__annotations__:
            raise ValueError(f'Choice initialized with keyword argument '
                             f'{repr(attr)}, which is not a valid attribute '
                             f'within the {type(self).__name__} type. Valid '
                             f'attributes are: {_attr_list(self)}')

        setattr(self, attr, value)

    def __setattr__(self, attr: str, value: Any) -> None:
        if attr not in self.__annotations__:
            raise AttributeError(f'Assignment to unsupported attribute '
                                 f'{type(self).__name__} within the '
                                 f'{type(self).__name__} type. Valid '
                                 f'attributes are: {_attr_list(self)}')

        super().__setattr__('_selection', attr)
        super().__setattr__(attr, value)


class NameMapping:
    """Stores a mapping from python to schema attribute names, and its
    inverse mapping. A key in the py_to_schema map is a python attribute
    name, e.g. "foo_bar", and the value is the schema name, e.g. "fooBar". A
    key in the schema_to_py map is a schema name, e.g. "fooBar", and the
    value is the python name, e.g. "foo_bar"."""

    def __init__(self, py_to_schema: Mapping[str, str]) -> None:
        self.py_to_schema = py_to_schema
        self.schema_to_py = {
            value: name
            for name, value in py_to_schema.items()
        }
        # no duplicates
        assert len(self.schema_to_py) == len(self.py_to_schema)


def to_jsonable(obj: Any, name_mappings: Mapping[type, NameMapping]) -> Any:
    # TODO Need to handle blobs (and possibly other XSD types)
    if isinstance(obj, str) or isinstance(obj, int) or isinstance(obj, float):
        return obj
    elif (isinstance(obj, datetime.datetime) or isinstance(obj, datetime.date)
          or isinstance(obj, datetime.time)):
        return obj.isoformat()
    elif isinstance(obj, datetime.timedelta):
        raise NotImplementedError('Time intervals are not supported.')
    elif isinstance(obj, Enum):
        return name_mappings[type(obj)].py_to_schema[obj.name]
    elif isinstance(obj, list):
        return [to_jsonable(item, name_mappings) for item in obj]
    elif isinstance(obj, Choice):
        return {
            name_mappings[type(obj)].py_to_schema[obj._selection]: \
                to_jsonable(getattr(obj, obj._selection), name_mappings)
        }
    else:
        if not isinstance(obj, Sequence):
            raise ValueError(
                f'Unable to to_jsonable object with unsupported type {type(obj)}.'
            )
        return {
            elem: to_jsonable(getattr(obj, attr), name_mappings) \
            for attr, elem in name_mappings[type(obj)].py_to_schema.items() \
            if getattr(obj, attr) is not None
        }


def _parse_interval(hours: str, minutes: Optional[str],
                    seconds: Optional[str]) -> Tuple[int, int, int, int, int]:
    """Return (hours, minutes, seconds, milliseconds, microseconds) from
    the specified timestamp parts, where the input arguments 'hours' and
    'minutes' are formatted as integers, while the input argument 'seconds' may
    be formatted as either an integer or a float.
    """
    seconds_dec = decimal.Decimal(seconds or 0)
    return_seconds = int(seconds_dec)
    fractional = seconds_dec - return_seconds
    milliseconds_dec = fractional * 1000
    milliseconds = int(milliseconds_dec)
    microseconds = int((milliseconds_dec - milliseconds) * 1000)

    return (int(hours), int(minutes or 0), return_seconds, milliseconds,
            microseconds)


def _parse_iso8601(isoformat: str
                   ) -> Union[datetime.date, datetime.time, datetime.datetime]:
    """Return an object parsed from the specified 'isoformat', which must be
    an ISO-8601 compatible date, time, or datetime, with the exception that
    none of week numbers, ordinal dates, nor dates without a year are
    supported. The type of object returned depends on the contents of
    'isoformat'. For example, "2018-06-25" yields a 'datetime.date',
    "12:34:18.332" yields a 'datetime.time', and "2016-01-01T08:54:33Z"
    yields a 'datetime.datetime'.
    """
    date_pattern = r'(?P<year>\d\d\d\d)-(?P<month>\d\d)-(?P<day>\d\d)'
    time_pattern = (r'(?P<hour>\d\d):'
                    r'(?P<minute>\d\d):'
                    r'(?P<second>\d\d(\.\d+)?)')
    zulu_pattern = r'(?P<zulu>Z)'
    offset_pattern = (r'(?P<offset_sign>[-+])(?P<offset_hours>\d\d)(:?'
                      r'(?P<offset_minutes>\d\d)(:?'
                      r'(?P<offset_seconds>\d\d(\.\d+)?))?)?')
    zone_pattern = f'{zulu_pattern}|{offset_pattern}'
    pattern = f'^({date_pattern})?[T ]?({time_pattern})?({zone_pattern})?$'

    match = re.match(pattern, isoformat)
    if not match:
        raise ValueError(f'Unable to parse as ISO-8601: {repr(isoformat)}')

    groups = match.groupdict()

    tzinfo = None
    if groups['zulu'] is not None:
        tzinfo = datetime.timezone.utc
    elif groups['offset_sign'] is not None:
        hours, minutes, seconds, milliseconds, microseconds = _parse_interval(
            groups['offset_hours'], groups['offset_minutes'],
            groups['offset_seconds'])

        sign = {'-': -1, '+': +1}[groups['offset_sign']]

        tzinfo = datetime.timezone(sign * datetime.timedelta(
            seconds=seconds,
            microseconds=microseconds,
            milliseconds=milliseconds,
            minutes=minutes,
            hours=hours))

    if groups['year'] is None:
        # It's just a time.
        hours, minutes, seconds, milliseconds, microseconds = _parse_interval(
            groups['hour'], groups['minute'], groups['second'])

        return datetime.time(
            hour=hours,
            minute=minutes,
            second=seconds,
            microsecond=(microseconds + 1000 * milliseconds),
            tzinfo=tzinfo)
    elif groups['hour'] is None:
        # It's just a date. Note that time zone information is ignored.
        return datetime.date(
            int(groups['year']), int(groups['month']), int(groups['day']))

    # Otherwise, it's a datetime.
    hours, minutes, seconds, milliseconds, microseconds = _parse_interval(
        groups['hour'], groups['minute'], groups['second'])

    return datetime.datetime(
        int(groups['year']), int(groups['month']), int(groups['day']), hours,
        minutes, seconds, microseconds + 1000 * milliseconds, tzinfo)


def from_jsonable(return_type: Any, obj: Any,
                  name_mappings: Mapping[type, NameMapping],
                  class_by_name: Mapping[str, type]) -> Any:
    # Note that while this function is annotated as returning any type, it in
    # fact returns a value having the specified 'return_type'.
    # TODO Need to handle blobs (and possibly other XSD types)

    # This case needs to be checked first, because if 'return_type' is a
    # 'typing.Union' (e.g. 'typing.Optional'), then it's not really a type,
    # and so the 'issubclass' checks will fail below. Strangely this is not
    # true for 'typing.List', which behaves like a type.
    if repr(return_type.__class__) == 'typing.Union':
        # 'typing.Union[..., None]' comes from 'typing.Optional[...]'.
        type_args = return_type.__args__
        assert len(type_args) == 2
        assert type(None) in type_args
        inner_type = [t for t in type_args if t is not type(None)][0]
        return from_jsonable(inner_type, obj, name_mappings, class_by_name)
    elif issubclass(return_type, (str, int, float)):
        return return_type(obj)
    elif issubclass(return_type,
                    (datetime.datetime, datetime.date, datetime.time)):
        if not isinstance(obj, str):
            raise ValueError(
                f'Unable to parse a {return_type} from a {type(object)}.')
        result = _parse_iso8601(obj)
        if not isinstance(result, return_type):
            raise ValueError(f'Expected a {return_type} but parsed a '
                             f'{type(result)} from {repr(obj)}')
        return result
    elif issubclass(return_type, datetime.timedelta):
        raise NotImplementedError('Time intervals are not supported.')
    elif issubclass(return_type, Enum):
        return return_type[name_mappings[return_type].schema_to_py[obj.name]]
    elif issubclass(return_type, list):
        elem_type, = return_type.__args__
        return [from_jsonable(elem_type, elem, name_mappings, class_by_name) \
                for elem in obj]
    else:
        # Assume that 'return_type' is derived from either 'Sequence' or
        # 'Choice', so that we can just invoke its constructor with keyword
        # arguments mapped from the keys and values of 'obj'. We know the types
        # of the attributes within 'return_type' by examining its
        # '__annotations__'.
        schema_to_py = name_mappings[return_type].schema_to_py
        attr_values = {}
        for elem, value in obj.items():
            attr = schema_to_py[elem]
            elem_annotation = return_type.__annotations__[attr]
            # If the element annotation spelled its type as a str, then it's a
            # forward declared type. Look up the actual class in class_by_name.
            if isinstance(elem_annotation, str):
                elem_type = class_by_name[elem_annotation]
            else:
                elem_type = elem_annotation

            attr_values[attr] = from_jsonable(elem_type, value, name_mappings,
                                              class_by_name)

        return return_type(**attr_values)
