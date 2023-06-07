from ast import *
from itertools import *
from sys import argv

from multiprocessing import Pool,cpu_count
from sympy import Polygon # for polygon algorithms (area, containment)


def chirotope_from_string(s,N):
	N3 = list(combinations(N,3))
	assert(len(N3) == len(s))
	chi = {}
	for i,(a,b,c) in enumerate(N3):
		if s[i] == '+': 
			x = +1 
		else:
			assert(s[i] == '-')
			x = -1
		chi[a,b,c] = chi[b,c,a] = chi[c,a,b] = x
		chi[b,a,c] = chi[c,b,a] = chi[a,c,b] = -x
	return chi
	

def chirotope_from_pointset(pts,N):
	def sgn(x): return (x>0)-(x<0)
	def o(p,q,r): return sgn((q[0]-p[0])*(r[1]-p[1]) - (q[1]-p[1])*(r[0]-p[0]))
	return {(a,b,c):o(pts[a],pts[b],pts[c]) for a,b,c in permutations(N,int(3))}


def chirotope_to_string(chi,N):
	return ''.join('+' if chi[I]>0 else '-' for I in combinations(N,3))


def edges_cross(chi,e,f):
	a,b = e
	c,d = f
	return ( chi[a,b,c]*chi[a,b,d] == -1 ) and (chi[a,c,d]*chi[b,c,d] == -1 )


def enum_structures(n,edge_crossings,selection=set()):
	maximal = True
	for e in edge_crossings:
		if not e in selection and not edge_crossings[e]&selection: # planarity
			if args.structure == 'spanningtree' and not Graph(list(selection|{e})).is_tree(): continue 
			maximal = False
			if selection and e < max(selection): continue
			for T in enum_structures(n,edge_crossings,selection|{e}):
				yield T
	if maximal:
		yield selection


def min_area_slow(triangulation,pts):
	G = Graph(list(triangulation))
#	print("edges",G.edges(labels=0))
#	print("pos",G.get_pos())
#	assert(G.is_planar())
	#G.set_pos(pts)
	#F = G.faces()
	F = [(a,b,c) for (a,b,c) in combinations(N,3) if G.has_edge(a,b) and G.has_edge(a,c) and G.has_edge(b,c)]
	assert(len([f for f in F if len(f) != 3]) <= 1) # only outer face might not be a triangle; outer face has largest area
	return min(float(abs(Polygon(*[pts[v] for v in f]).area)) for f in F)


def min_angle_slow(triangulation,pts):
	G = Graph(list(triangulation))
#	print("edges",G.edges(labels=0))
#	print("pos",G.get_pos())
#	assert(G.is_planar())
	#G.set_pos(pts)
	#F = G.faces()
	F = [(a,b,c) for (a,b,c) in combinations(N,3) if G.has_edge(a,b) and G.has_edge(a,c) and G.has_edge(b,c)]
	assert(len([f for f in F if len(f) != 3]) <= 1) # only outer face might not be a triangle; outer face has large angles
	return min(min(float(a) for a in Polygon(*[pts[v] for v in f]).angles.values()) for f in F)


def min_angle(triangulation,pts):
	pts_vec = [vector(RR,p) for p in pts]
	G = Graph(list(triangulation))
	F = [(a,b,c) for (a,b,c) in combinations(N,3) if G.has_edge(a,b) and G.has_edge(a,c) and G.has_edge(b,c)]
	angles = []
	for f in F:
		f_vecs = [(pts_vec[f[i-1]]-pts_vec[f[i]]).normalized() for i in range(3)]
		angles += [arccos(f_vecs[i-1]*f_vecs[i]) for i in range(3)]
	return min(angles)



def min_area(triangulation,pts):
	pts_vec = [vector(RR,(0,)+p) for p in pts]
	G = Graph(list(triangulation))
	F = [(a,b,c) for (a,b,c) in combinations(N,3) if G.has_edge(a,b) and G.has_edge(a,c) and G.has_edge(b,c)]
	areas = []
	for f in F:
		f_vecs = [(pts_vec[f[i-1]]-pts_vec[f[i]]) for i in range(3)]
		areas.append(abs(f_vecs[0].cross_product(f_vecs[1])))
	#print(areas)
	return min(areas)



import argparse
parser = argparse.ArgumentParser()

parser.add_argument("structure",type=str,choices=['spanningtree','triangulation','triangulation+angle','triangulation+area'],help="structure for flipgraph")

parser.add_argument("fp",type=str,help="input file path") 
parser.add_argument("--n",type=int,help="number of points")

parser.add_argument("--happytest","-ht",action='store_true', help="test happyness")
parser.add_argument("--maxdistpair","-mdp",action='store_true', help="find pair at max distance")

parser.add_argument("--only",type=int,default=None,help="only test one line")
parser.add_argument("--parallel","-P",action='store_false',help="use flag to disable parallel computations (enabled by default)")


args = parser.parse_args()
print("args",args)



stat = []
fp = args.fp

ft = fp.split(".")[-1]
assert(ft in ['chi','json']) # check file type is supported

for ct,line in enumerate(open(fp).readlines()):
	if args.only != None and args.only != ct+1: continue  # note off by one because qsub does not allow index 0

	if ft == 'chi':
		n = args.n
		N = range(n)
		chi = chirotope_from_string(line.replace("\n",""),N)

	if ft == 'json':
		pts = literal_eval(line)
		n = len(pts)
		N = range(n)
		chi = chirotope_from_pointset(pts,N)

	assert(0 not in chi.values()) # assert point set is non-degenerate
	chi_str = chirotope_to_string(chi,N)
	print("test #",ct,":",chi_str)

	edges = list(combinations(N,2))
	edge_crossings = {e:{f for f in edges if not set(e)&set(f) and edges_cross(chi,e,f)} for e in edges}

	structs = list(enum_structures(n,edge_crossings))
	print("number of",args.structure,":",len(structs))

	group = {}

	G = Graph()
	for t in range(len(structs)):
		G.add_vertex(t)

		t_e = list(sorted(structs[t]))
		if t_e[0] not in group: group[t_e[0]] = []
		if t_e[1] not in group: group[t_e[1]] = []
		group[t_e[0]].append(t)
		group[t_e[1]].append(t)

	for e in group:
		for t1,t2 in combinations(group[e],2):
			if len(structs[t1]&structs[t2]) == len(structs[t1])-1:
				G.add_edge(t1,t2)


	diam = G.diameter()
	print("diameter of flip graph:",diam)
	stat.append(diam)

	if args.maxdistpair:
		H = G.distance_graph(diam)
		for u,v in H.edges(labels=0):
			print("distance",diam,"@",structs[u],structs[v])
			break


#	print("sym",len(G),G.automorphism_group().order())
	#print("G",G.sparse6_string())

	if args.happytest:
		print("happytest")
		A_G = G.automorphism_group()
		pairs_to_test = set()
		deg1_vertices = G.degree().count(1)

		def test_happy(t1):
			if t1 == min(A_G.orbit(t1)):
				H = Graph(G.edges())
				for v in range(-deg1_vertices-1,0):
					H.add_edge(t1,v) # add sufficiently many degree-1 dummy vertices to mark vertex t1

				A_H = H.automorphism_group()
				for t2 in G:
					if t2 != -1 and t2 != t1 and t2 == min(A_H.orbit(t2)) and structs[t1]&structs[t2]:
						test_pair(t1,t2)


		def test_pair(t1,t2):
			d = G.distance(t1,t2)
			if args.structure == 'spanningtree':
				common_edges = structs[t1]&structs[t2]
				G12 = G.subgraph(vertices=[t for t in G if common_edges.issubset(structs[t])])
			elif args.structure in ['triangulation+angle','triangulation+area']:
				G12 = G.subgraph(vertices=[t for t in G if weight[t] >= min(weight[t1],weight[t2])])
			else:
				exit("not implemented")
			
			d12 = G12.distance(t1,t2)
			if d12 != d:
				print("t1",t1)
				print("t2",t2)
				with open("error.txt","a") as f:
					f.write(str(("unhappy",chi_str,t1,t2))+"\n")
				#exit("found counterexample to conjecture!!")
				return False
			return True


		if args.structure == 'triangulation+angle':
			print("compute weights")
			weight = {t:min_angle(structs[t],pts) for t in range(len(structs))}
			print("weights:",weight)
		if args.structure == 'triangulation+area':
			print("compute weights")
			weight = {t:min_area(structs[t],pts) for t in range(len(structs))}
			print("weight:",weight)
			

		if args.parallel:
			result = Pool(cpu_count()).map(test_happy,range(len(structs))) # parallel
		else:
			result = map(test_happy,range(len(structs))) # single threaded
	
		if False not in result:
			print("all happy :)")
		else:
			print(80*"-")
			print("!! found unhappy !!")
			print(80*"-")
			exit()

	print("")

print("all fine.")
print("diam min max",min(stat),max(stat))