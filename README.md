# SPARQLSyntax

## SPARQL 1.1 Parser and Abstract Syntax

 - [Features](#features)
 - [Building](#building)
 - [Swift Package Manager](#swift-package-manager)
 - [Command Line Usage](#command-line-usage)
 - [API](#api)

### Features

* [SPARQL 1.1] Parser, Tokenizer, and Serializer available via both API and command line tool
* Abstract syntax representation of SPARQL queries, aligned with the [SPARQL Algebra]

[SPARQL 1.1]: https://www.w3.org/TR/sparql11-query
[SPARQL Algebra]: https://www.w3.org/TR/sparql11-query/#sparqlAlgebra

### Building

```
% swift build -c release
```

### Swift Package Manager

To use SPARQLSyntax with projects using the [Swift Package Manager],
add the following to your project's `Package.swift` file:

  ```swift
  dependencies: [
    .package(url: "https://github.com/kasei/swift-sparql-syntax.git", .upToNextMinor(from: "0.0.91"))
  ]
  ```

[Swift Package Manager]: https://swift.org/package-manager

### Command Line Usage

A command line tool, `sparql-parser`, is provided to parse a SPARQL query and
print its parsed query algebra, its tokenization, or a pretty-printed SPARQL
string:

```
% ./.build/release/sparql-parser 
Usage: ./.build/release/sparql-parser [-v] COMMAND [ARGUMENTS]
       ./.build/release/sparql-parser parse query.rq
       ./.build/release/sparql-parser lint query.rq
       ./.build/release/sparql-parser tokens query.rq
```

To "lint", or "pretty print", a SPARQL query:

```
% cat examples/messy.rq
prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
select    ?s
where{
?s geo:lat ?lat ;geo:long ?long   ;
	FILTER(?long < -117.0)
FILTER(?lat >= 31.0)
  FILTER(?lat <= 33.0)
} ORDER BY ?s

% ./.build/release/sparql-parser lint examples/messy.rq 
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
SELECT ?s WHERE {
    ?s geo:lat ?lat ;
        geo:long ?long ;
    FILTER (?long < - 117.0)
    FILTER (?lat >= 31.0)
    FILTER (?lat <= 33.0)
}
ORDER BY ?s

```

To parse the query and print the resulting query algebra:

```
% ./.build/release/sparql-parser parse examples/messy.rq
Query
  Select { ?s }
        Project { ?s }
          OrderBy { ?s }
            Filter (((?long < -117.0) && (?lat >= 31.0)) && (?lat <= 33.0))
              BGP
                ?s <http://www.w3.org/2003/01/geo/wgs84_pos#lat> ?lat .
                ?s <http://www.w3.org/2003/01/geo/wgs84_pos#long> ?long .

```

### API

The `SPARQLSyntax` library provides an API for parsing SPARQL queries
and accessing the resulting abstract data structures.
The primary components of this API are:

* `struct Term` - A representation of an RDF Term (IRI, Literal, or Blank node)
* `enum Algebra` - A representation of the query pattern closely aligned with the formal SPARQL Algebra
* `struct Query` - A representation of a SPARQL query including: a query form (`SELECT`, `ASK`, `DESCRIBE`, or `CONSTRUCT`), a query `Algebra`, and optional base URI and dataset specification
* `struct SPARQLParser` - Parses a SPARQL query String/Data and returns a `Query`
* `struct SPARQLSerializer` - Provides the ability to serialize a query, optionally applying "pretty printing" formatting
