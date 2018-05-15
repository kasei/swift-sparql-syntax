# swift-sparql-parser

## A Swift SPARQL Parser

### Build

```
% swift build -c release
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
% cat messy.rq
prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
select    ?s
where{
?s geo:lat ?lat ;geo:long ?long   ;
	FILTER(?long < -117.0)
FILTER(?lat >= 31.0)
  FILTER(?lat <= 33.0)
} ORDER BY ?s

% ./.build/release/sparql-parser lint messy.rq 
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
SELECT ?s WHERE {
	?s geo:lat ?lat ;
		geo:long ?long ;
	FILTER(?long < - 117.0)
	FILTER(?lat >= 31.0)
	FILTER(?lat <= 33.0)
}
ORDER BY ?s
```

To parse the query and print the resulting query algebra:

```
% ./.build/release/sparql-parser parse messy.rq
Query
  Select { s }
        OrderBy { ?s }
          Project ["s"]
            Filter ((?lat <= 33.0) && ((?lat >= 31.0) && (?long < -117.0)))
              BGP
                ?s <http://www.w3.org/2003/01/geo/wgs84_pos#lat> ?lat .
                ?s <http://www.w3.org/2003/01/geo/wgs84_pos#long> ?long .
```

### API

The `SPARQLSyntax` library provides an API for parsing SPARQL queries and
accessing the resulting data structures. The primary components of this API
are:

* `struct Query` - A representation of a SPARQL query including: a query form (SELECT, ASK, DESCRIBE, or CONSTRUCT), a query `Algebra`, and optional base URI and dataset specification
* `struct SPARQLParser` - Parses a SPARQL query String/Data and returns a `Query`
* `enum Algebra` - A representation of the query pattern closely aligned with the formal SPARQL Algebra
* `struct Term` - A representation of an RDF Term (IRI, Literal, or Blank node)
