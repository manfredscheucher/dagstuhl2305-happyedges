# description

a program to investigate the flip graph of structures like triangulations or spanning trees.
by default the diameter is computed.


# usage

the first parameter is {spanningtree,triangulation,triangulation+angle,triangulation+area}.
the second parameter is the path to the input file.
each line in the input file encodes the coordinates of a point set in json format.


## spanningtree

with the optional "-ht" parameter the program tests whether the flip-graph is happy, that is,
between any two spanning trees $T_1,T_2$ there exists a shortest path 
such that all spanning trees along the path contain the common edges of $T_1$ and $T_2$ 
(if $e$ is an edge in $T_1$ and $T_2$, then $e$ is contained in all vertices along the path)  

```
sage check_flipgraph.sage spanningtree ot/ot4.json -ht
```


## triangulation+angle 

with the optional "-ht" parameter the program tests whether the flip-graph is happy, that is,
between any two spanning trees $T_1,T_2$ there exists a shortest path 
such that all triangulations along the path have no smaller angle than $T_1$ and $T_2$ 

```
sage check_flipgraph.sage triangulation+angle ot/ot4.json -ht
```


## triangulation+area 

with the optional "-ht" parameter the program tests whether the flip-graph is happy, that is,
between any two spanning trees $T_1,T_2$ there exists a shortest path 
such that all triangulations along the path have no smaller area than $T_1$ and $T_2$ 

```
sage check_flipgraph.sage triangulation+area ot/ot4.json -ht
```

