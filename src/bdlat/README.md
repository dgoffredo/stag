bdlat
=====
This module defines data types used to represent BDE "attribute types,"
which are defined in the "bdlat" package of the BDE C++ libraries, as well
as procedures that convert SXML nodes parsed from an XSD document into
structural representations of the defined types.

For example, suppose that the following XSD:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
            xmlns:ext="http://www.xsd.com/extensions">

    <xs:complexType name="SomeChoice">
    <xs:choice>
    <xs:element name="foo" type="xs:decimal" />
    <xs:element name="bar" type="xs:string" />
    </xs:choice>
    </xs:complexType>

    <xs:simpleType name="Color">
    <xs:restriction base="xs:string">
        <xs:enumeration value="RED" ext:id="0" />
        <xs:enumeration value="GREEN" ext:id="1"/>
        <xs:enumeration value="BLUE" ext:id="2" />
    </xs:restriction>
    </xs:simpleType>

</xs:schema>
```

were converted into the following SXML:

```scheme
(*TOP*
    (@
    (*NAMESPACES*
    (xs "http://www.w3.org/2001/XMLSchema")
    (ext "http://www.xsd.com/extensions")))
    (*PI* xml "version=\"1.0\" encoding=\"UTF-8\"")
    (xs:schema
    (xs:complexType
    (@ (name "SomeChoice"))
    (xs:choice
        (xs:element (@ (type "xs:decimal") (name "foo")))
        (xs:element (@ (type "xs:string") (name "bar")))))
    (xs:simpleType
    (@ (name "Color"))
    (xs:restriction
        (@ (base "xs:string"))
        (xs:enumeration (@ (ext:id "0") (value "RED")))
        (xs:enumeration (@ (ext:id "1") (value "GREEN")))
        (xs:enumeration (@ (ext:id "2") (value "BLUE")))))))
```

Then the following program (where `doc` is the SXML above):

```scheme
(require (prefix-in bdlat: "bdlat.rkt"))

(print (bdlat:sxml->types doc))
```

would print the following to standard output:

```scheme
(list 
    (choice "SomeChoice" #f 
    (list (element "foo" (basic "decimal") #f #f)
          (element "bar" (basic "string") #f #f)))
            
    (enumeration "Color" #f 
    (list (enumeration-value "RED" 0 #f)
          (enumeration-value "GREEN" 1 #f) 
          (enumeration-value "BLUE" 2 #f))))
```

where the `#f` and `#:omit` elements are placeholders for missing documentation
and default values.