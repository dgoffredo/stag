xsd-util
========
Ideally, one could just use the `sxml` library to parse an XSD file and pass it
to the `bdlat.rkt` module to produce types (e.g. sequences, enumerations).
However, XSD has more structure than plain XML, in particular with regard to
namespaces. XSD namespaces are just XML namespaces, but additionally there are
special attributes in XSD that refer to possibly namespace qualified names in
the document. In particular, the following two examples:

    <xs:element name="color" type="tns:Color" />

and

    <xs:restriction base="xs:string">

contain attributes (`type` and `base`, respectively) whose value is a
namespace qualified name referring to some XSD entity.

This is significant to the problem of code generation because the "string"
defined in the XSD namespace is distinct from, say, some "string" type
defined in a schema. The code generator must be able to distinguish between
the two, but changing the names (aliases) of namespaces in the XSD document
doesn't change the values of these attributes -- the attribute values are
still just strings.

The `xsd-util.rkt` module accounts for this to produce an SXML parsing of
an XSD document whose usage of namespace is consistent in both XML tags and
certain attribute values.

The `bdlat.rkt` module requires that the XSD namespace is aliased as `xs` and
that the "extensions" namespace (whatever it happens to be) is aliased as
`ext`. The `xsd->sxml` procedure in `xsd-util.rkt` always produces such a 
schema.