
'''serialization utilities used in generated classes

TODO
'''

from enum import Enum
from typing import Mapping

import datetime

class NameMapping:
    def __init__(self, py_to_schema : Mapping[str, str]):
        self.py_to_schema = py_to_schema
        self.schema_to_py = {
                value: name for name, value in py_to_schema.items()
        }


def to_json(obj, name_mappings):
    # TODO Need to handle blobs (and possibly other XSD types)
    if isinstance(obj, str) or isinstance(obj, int) or isinstance(obj, float):
        return obj
    elif (isinstance(obj, datetime.datetime) or
          isinstance(obj, datetime.date) or
          isinstance(obj, datetime.time)):
        return obj.isoformat()
    elif isinstance(obj, datetime.timedelta):
        raise NotImplementedError() # TODO
    elif isinstance(obj, Enum):
        return name_mappings[type(obj)].py_to_schema[obj.name]
    elif isinstance(obj, list):
        return [to_json(item, name_mappings) for item in obj]
    elif hasattr(obj, '_selection'):
        return {
            name_mappings[type(obj)].py_to_schema[obj._selection()]: \
                to_json(getattr(obj, obj._selection()), name_mappings)
        }
    else:
        return {
            elem: to_json(getattr(obj, attr), name_mappings) \
            for attr, elem in name_mappings[type(obj)].py_to_schema.items() \
            if getattr(obj, attr) is not None
        }


def from_json(return_type, obj, name_mappings):
    # TODO Need to handle blobs (and possibly other XSD types)
    if isinstance(obj, str) or isinstance(obj, int) or isinstance(obj, float):
        return return_type(obj)
    elif (isinstance(obj, datetime.datetime) or
          isinstance(obj, datetime.date) or
          isinstance(obj, datetime.time)):
        raise NotImplementedError() # TODO
    elif isinstance(obj, datetime.timedelta):
        raise NotImplementedError() # TODO
    elif isinstance(obj, Enum):
        return type(obj)[name_mappings[type(obj)].schema_to_py[obj.name]]
    elif isinstance(obj, list):
        elem_type, = return_type.__args__
        return [from_json(elem_type, elem, name_mappings) for elem in obj]
    else:
        schema_to_py = name_mappings[type(obj)].schema_to_py
        attr_values = {}
        for elem, value in obj.items():
            attr = schema_to_py[elem]
            elem_type = type(obj).__annotations__[attr]
            attr_values[attr] = from_json(elem_type, value, name_mappings)
        return return_type(**attr_values)
