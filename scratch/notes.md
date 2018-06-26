TODO
----
- Fix `to_json` and `from_json`.
- Support datetimes in `from_json`.
- Elide unmodified names from `_name_mappings` (and modify `to_json` and
  `from_json` to account for this).
- Uniquify the type arguments to `typing.Union` in `Choice` initializers.