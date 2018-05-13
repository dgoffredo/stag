
'''base class representing a discriminated union of named attributes

TODO
'''

from typing import Mapping 

class NamedUnion:
    def _types(self) -> Mapping[str, type]:
        return type(self).__annotations__ # {attribute: type}

    def _name(self) -> str:
        return type(self).__name__

    def _selection(self) -> str:
        key, = self._types().keys() & self.__dict__.keys()
        return key

    def __init__(self, **kwarg):
        name = self._name()
        if len(kwarg) != 1:
            raise TypeError(f'{name} must contain exactly one value, but '
                            f'{len(kwarg)} arguments were passed to its '
                            '__init__.')
        (attr, value), = kwarg.items()
        types = self._types()
        if attr not in types:
            raise TypeError(f'{name} constructor passed unexpected keyword '
                            f'argument: {attr}. The supported arguments are: '
                            f'{tuple(types.keys())}')

        object.__setattr__(self, attr, value)

    def __setattr__(self, attr, value):
        name = self._name()
        # Anything is an error, but for diagnostics' sake, distinguish between
        # when the attribute name is one of those known to this type, and when
        # it is not.
        if attr in _types():
            raise TypeError(f'{name} is immutable.')
        else:
            raise TypeError(f'{name} is immutable, and {attr} is not one of '
                            'its attributes.')

    def __getattr__(self, attr):
        name = self._name()
        types = self._types()
        # This special method is not needed, since the only attribute defined
        # on an instance is its selected choice. Here we improve diagnostics.
        # If the requested attribute is among the union's choices, but is not
        # the current selection, then mention that. Otherwise default behavior.
        if attr in types.keys() - self.__dict__.keys():
            raise ValueError(f'Cannot get {repr(attr)} attribute of this '
                             f'this {name} instance because its current '
                             f'selection is {repr(self._selection())}')

        return object.__getattr__(self, attr)
