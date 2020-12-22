Extensions to SPARQL 1.1
========================

EXTENSION-001: Window Functions
-------------

*Status*: Fully implemented
*branch*: master

Support for [window functions](https://github.com/w3c/sparql-12/issues/47) in `SELECT` or `HAVING` clauses.

Window functions take the form:

`expression OVER (PARTITION BY partition_defn ORDER BY comparators [windowframe] )`

Expressions must contain a Valid window function:

* `RANK()`
* `DENSE_RANK()`
* `ROW_NUMBER()`
* `NTILE(integer)`
* aggregates (without the use of `DISTINCT`)
* extension window functions identified by IRI or PrefixedName (just like non-window functions)

Sort `comparators` are the same as in an `ORDER BY` clause.

The `windowframe` takes one of the following forms:

`frametype BETWEEN UNBOUNDED AND n PRECEDING`
`frametype BETWEEN UNBOUNDED AND CURRENT ROW`
`frametype BETWEEN UNBOUNDED AND n FOLLOWING`
`frametype BETWEEN UNBOUNDED AND n PRECEDING`
`frametype BETWEEN n PRECEDING AND m PRECEDING`
`frametype BETWEEN n PRECEDING AND CURRENT ROW`
`frametype BETWEEN n PRECEDING AND m FOLLOWING`
`frametype BETWEEN n PRECEDING AND UNBOUNDED`
`frametype BETWEEN CURRENT ROW AND n FOLLOWING`
`frametype BETWEEN CURRENT ROW AND n FOLLOWING`
`frametype BETWEEN CURRENT ROW AND n FOLLOWING`
`frametype BETWEEN CURRENT ROW AND UNBOUNDED`
`frametype BETWEEN n FOLLOWING AND n FOLLOWING`
`frametype BETWEEN n FOLLOWING AND UNBOUNDED`

where `frametype` is either `ROWS` or `RANGE`.

EXTENSION-002: SPARQL*
-------------

*Status*: Parsing SPARQL* embedded triple patterns and `BIND` expressions resulting in AST using standard RDF reification is supported. Use of embedded triple patterns in `CONSTRUCT` patterns is not implemented.
*branch*: sparql-star

[SPARQL*](https://arxiv.org/pdf/1406.3399.pdf) syntax for expressing reification:

```
SELECT ?age ?src WHERE {
	?bob foaf:name "Bob" .
	<< ?bob foaf:age ?age >> dct:source ?src .
}
```

EXTENSION-003: `GROUP_CONCAT` ordering
-------------

*Status*: AST support is implemented; parsing is not implemented yet.
*branch*: sparql-12

Allows values to be sorted before string concatenation occurs:

```
GROUP_CONCAT(DISTINCT ?names; SEPARATOR=", ", ORDER BY ?names)
```

EXTENSION-004: `xsd:duration` support
-------------

*Status*: AST support for casts and datetime functions, and init/property Term extensions implemented
*branch*: sparql-12

Allows SPARQL function-style casting to `xsd:time` and `xsd:duration`, and use of `ADJUST` function.

