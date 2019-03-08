# SPARQLSyntax

## SPARQL 1.1 Parser and Abstract Syntax

 - [Features](#features)
 - [Building](#building)
 - [Swift Package Manager](#swift-package-manager)
 - [Command Line Usage](#command-line-usage)
 - [API](#api)
   - [Term](#term)
   - [Triple, Quad, TriplePattern and QuadPattern](#triple-quad-triplepattern-and-quadpattern)
   - [Algebra](#algebra)
   - [Expression](#expression)
   - [Query](#query)
   - [SPARQLParser](#sparqlparser)
   - [SPARQLSerializer](#sparqlserializer)

### Features

* [SPARQL 1.1] Parser, Tokenizer, and Serializer available via both API and command line tool
* Abstract syntax representation of SPARQL queries, aligned with the [SPARQL Algebra]

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
* `enum Expression` - A representation of a logical expression
* `struct Query` - A representation of a SPARQL query including: a query form (`SELECT`, `ASK`, `DESCRIBE`, or `CONSTRUCT`), a query `Algebra`, and optional base URI and dataset specification
* `struct SPARQLParser` - Parses a SPARQL query String/Data and returns a `Query`
* `struct SPARQLSerializer` - Provides the ability to serialize a query, optionally applying "pretty printing" formatting

#### `Term`

`struct Term` represents an [RDF Term] (an IRI, a blank node, or an RDF Literal).
`Term` also provides some support for XSD numeric types,
bridging between `Term`s and `enum NumericValue` which provides numeric functions and [type-promoting operators](https://www.w3.org/TR/xpath20/#promotion).

#### `Triple`, `Quad`, `TriplePattern`, and `QuadPattern`

`struct Triple` and `struct Quad` combine `Term`s into RDF triples and quads.
`struct TriplePattern` and `struct QuadPattern` represent patterns which can be matched by concrete `Triple`s and `Quad`s.
Instead of `Term`s, patterns are comprised of a `enum Node` which can be either a bound `Term`, or a named `variable`.

#### `Algebra`

`enum Algebra` is an representation of a query pattern aligned with the [SPARQL Algebra].
Cases include simple graph pattern matching such as `triple`, `quad`, and `bgp`,
and more complex operators that can be used to join other `Algebra` values
(e.g. `innerJoin`, `union`, `project`, `distinct`).

`Algebra` provides functions and properties to access features of graph patterns including:
variables used; and in-scope, projectable, and "necessarily bound" variables.
The structure of `Algebra` values can be modified using a rewriting API that can:
bind values to specific variables; replace entire `Algebra` sub-trees; and rewrite `Expression`s used within the `Algebra`.

#### `Expression`

`enum Expression` represents a logical expression of variables, values, operators, and functions
that can be evaluated within the context of a query result to produce a  `Term` value.
`Expression`s are used in the following `Algebra` operations: filter, left outer join ("OPTIONAL"), extend ("BIND"), and aggregate.

`Expression`s may be modified using a similar rewriting API to that provided by `Algebra` that can:
bind values to specific variables; and replace entire `Expression` sub-trees.

#### `Query`

`struct Query` represents a SPARQL Query and includes:

* a query form (`SELECT`, `ASK`, `DESCRIBE`, or `CONSTRUCT`, and any associated data such as projected variables, or triple patterns used to `CONSTRUCT` a result graph)
* a graph pattern (`Algebra`)
* an optional base URI
* an optional dataset specification

#### `SPARQLParser`

`struct SPARQLParser` provides an API for parsing a SPARQL 1.1 query string and producing a `Query`.

#### `SPARQLSerializer`

`struct SPARQLSerializer` provides an API for serializing SPARQL 1.1 queries, optionally applying "pretty printing" rules to produce consistently formatted output.
It can serialize both structured queries (`Query` and `Algebra`) and unstructured queries (a query `String`).
In the latter case, serialization can be used even if the query contains syntax errors (with data after the error being serialized as-is).

[SPARQL 1.1]: https://www.w3.org/TR/sparql11-query
[SPARQL Algebra]: https://www.w3.org/TR/sparql11-query/#sparqlAlgebra
[Swift Package Manager]: https://swift.org/package-manager
[RDF Term]: https://www.w3.org/TR/sparql11-query/#sparqlBasicTerms
