TODO
----
- Test `to_jsonable` and `from_jsonable`.
- Elide unmodified names from `_name_mappings` (and modify `to_jsonable` and
  `from_jsonable` to account for this).
- Uniquify the type arguments to `typing.Union` in `Choice` initializers.