from itertools import *
from sys import argv


def edges_cross(chi,e,f):
	a,b = e
	c,d = f
	return ( chi[a,b,c]*chi[a,b,d] == -1 ) and (chi[a,c,d]*chi[b,c,d] == -1 )


def enum_trees(n,edge_crossings,selection=set()):
	if len(selection) == n-1:
		yield selection
	else:
		for e in edge_crossings:
			if selection and e < max(selection): continue
			if not e in selection and not edge_crossings[e]&selection:
				for T in enum_trees(n,edge_crossings,selection|{e}):
					yield T


n = int(argv[1])
N = range(n)

stat = []
fp = argv[2]
for ct,line in enumerate(open(fp).readlines()):
	line=line.replace("\n","")
	N3 = list(combinations(N,3))
	chi = {}
	for i,(a,b,c) in enumerate(N3):
		x = +1 if line[i] == '+' else -1
		chi[a,b,c] = chi[b,c,a] = chi[c,a,b] = x
		chi[b,a,c] = chi[c,b,a] = chi[a,c,b] = -x

	print(ct,line)#chi)

	edges = list(combinations(N,2))
	#		print("o",BL.o)
	edge_crossings = {e:{f for f in edges if not set(e)&set(f) and edges_cross(chi,e,f)} for e in edges}
	#print("edge_crossings",edge_crossings)

	trees = list(enum_trees(n,edge_crossings))
	print("trees",len(trees))
	#for T in trees: print(T)

	E = []
	for t1,t2 in combinations(range(len(trees)),2):
		if len(trees[t1]&trees[t2]) == n-2:
			E.append([t1,t2])

	G = Graph(E)
	diam = G.diameter()
	print("diam",diam)
	stat.append(diam)
	continue
#	print("sym",len(G),G.automorphism_group().order())
	#print("G",G.sparse6_string())
	A_G = G.automorphism_group()
	assert(min(G.degree())>1) # add dummy node to mark vertex
	for t1 in G:
		if t1 == min(A_G.orbit(t1)):
			H = Graph(G.edges())
			H.add_vertex(-1)
			H.add_edge(t1,-1)
			A_H = H.automorphism_group()
			for t2 in G:
				if t2 != -1 and t2 != t1 and t2 == min(A_H.orbit(t2)):
					d = G.distance(t1,t2)
					common_edges = trees[t1]&trees[t2]
					if not common_edges: continue
					G12 = G.subgraph(vertices=[t for t in G if common_edges.issubset(trees[t])])
					d12 = G12.distance(t1,t2)
					if d12 != d:
						print("t1",t1)
						print("t2",t2)
						exit("found!")

print("fine.")
print("diam",min(stat),max(stat))