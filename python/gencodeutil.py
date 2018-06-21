'''serialization utilities used in generated classes

TODO
'''

from enum import Enum
from typing import Any, Dict, Iterator, List, Mapping, Tuple, Type, Union

import datetime


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

        self._selection = attr
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


def to_json(obj: Any, name_mappings: Mapping[type, NameMapping]) -> Any:
    # TODO Need to handle blobs (and possibly other XSD types)
    if isinstance(obj, str) or isinstance(obj, int) or isinstance(obj, float):
        return obj
    elif (isinstance(obj, datetime.datetime) or isinstance(obj, datetime.date)
          or isinstance(obj, datetime.time)):
        return obj.isoformat()
    elif isinstance(obj, datetime.timedelta):
        raise NotImplementedError()  # TODO
    elif isinstance(obj, Enum):
        return name_mappings[type(obj)].py_to_schema[obj.name]
    elif isinstance(obj, list):
        return [to_json(item, name_mappings) for item in obj]
    elif hasattr(obj, '_selection'):  # TODO
        return {
            name_mappings[type(obj)].py_to_schema[obj._selection]: \
                to_json(getattr(obj, obj._selection), name_mappings)
        }
    else:  # TODO
        return {
            elem: to_json(getattr(obj, attr), name_mappings) \
            for attr, elem in name_mappings[type(obj)].py_to_schema.items() \
            if getattr(obj, attr) is not None
        }


def from_json(return_type: Any, obj: Any,
              name_mappings: Mapping[type, NameMapping]) -> Any:
    # Note that while this function is annotated as returning any type, it in
    # fact returns a value having the specified 'return_type'.
    # TODO Need to handle blobs (and possibly other XSD types)
    if isinstance(obj, str) or isinstance(obj, int) or isinstance(obj, float):
        return return_type(obj)
    elif (isinstance(obj, datetime.datetime) or isinstance(obj, datetime.date)
          or isinstance(obj, datetime.time)):
        raise NotImplementedError()  # TODO
    elif isinstance(obj, datetime.timedelta):
        raise NotImplementedError()  # TODO
    elif isinstance(obj, Enum):
        return type(obj)[name_mappings[type(obj)].schema_to_py[obj.name]]
    elif isinstance(obj, list):
        elem_type, = return_type.__args__
        return [from_json(elem_type, elem, name_mappings) for elem in obj]
    else:  # TODO
        schema_to_py = name_mappings[type(obj)].schema_to_py
        attr_values = {}
        for elem, value in obj.items():
            attr = schema_to_py[elem]
            elem_type = type(obj).__annotations__[attr]
            attr_values[attr] = from_json(elem_type, value, name_mappings)
        return return_type(**attr_values)
