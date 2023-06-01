from ast import *
from itertools import *
from sys import argv

from multiprocessing import Pool,cpu_count


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


def enum_trees(n,edge_crossings,selection=set(),I_dont_care_if_it_is_a_tree=False):
	if len(selection) == n-1:
		if Graph(list(selection)).is_tree() or I_dont_care_if_it_is_a_tree:
			yield selection
	else:
		for e in edge_crossings:
			if selection and e < max(selection): continue
			if not e in selection and not edge_crossings[e]&selection:
				for T in enum_trees(n,edge_crossings,selection|{e}):
					yield T




import argparse
parser = argparse.ArgumentParser()

parser.add_argument("n",type=int,help="number of points")
parser.add_argument("fp",type=str,help="input file path")
parser.add_argument("--chirotope","-c",action='store_true', help="input file encodes chirotopes; by default json/coordinates")
parser.add_argument("--happytest","-ht",action='store_true', help="test happyness")
parser.add_argument("--maxdistpair","-mdp",action='store_true', help="find pair at max distance")

parser.add_argument("--only",type=int,default=None,help="only test one line")
parser.add_argument("--parallel","-P",action='store_false',help="use flag to disable parallel computations (enabled by default)")

args = parser.parse_args()
print("args",args)


n = args.n
N = range(n)

stat = []
fp = args.fp
for ct,line in enumerate(open(fp).readlines()):
	if args.only != None and args.only != ct+1: continue  # note off by one because qsub does not allow index 0

	if args.chirotope:
		chi = chirotope_from_string(line.replace("\n",""),N)

	else:
		pts = literal_eval(line)
		chi = chirotope_from_pointset(pts,N)

	assert(0 not in chi.values()) # degenerate
	chi_str = chirotope_to_string(chi,N)
	print("test #",ct,":",chi_str)

	edges = list(combinations(N,2))
	#		print("o",BL.o)
	edge_crossings = {e:{f for f in edges if not set(e)&set(f) and edges_cross(chi,e,f)} for e in edges}
	#print("edge_crossings",edge_crossings)

	trees = list(enum_trees(n,edge_crossings))
	print("trees",len(trees))
	#for T in trees: print(T)

	E = []
	group = {}
	for t in range(len(trees)):
		t_e = list(sorted(trees[t]))
		if t_e[0] not in group: group[t_e[0]] = []
		if t_e[1] not in group: group[t_e[1]] = []
		group[t_e[0]].append(t)
		group[t_e[1]].append(t)

	for e in group:
		for t1,t2 in combinations(group[e],2):
			if len(trees[t1]&trees[t2]) == n-2:
				E.append([t1,t2])

	G = Graph(E)
	diam = G.diameter()
	print("diam",diam)
	stat.append(diam)

	if args.maxdistpair:
		#dist = G.distance_matrix()
		#for u,v in combinations(G,2):
		#	if dist[u][v] >= diam:
		#		print("distance",dist[u][v],":",trees[u],trees[v])
		#		break

		H = G.distance_graph(diam)
		for u,v in H.edges(labels=0):
			print("distance",diam,"@",trees[u],trees[v])
			break

	#for u,v in combinations(G,2):
	#	if G.distance(u,v) >= n:
	#		print("distance",diam,"@",trees[u],trees[v])
	#		break


#	print("sym",len(G),G.automorphism_group().order())
	#print("G",G.sparse6_string())

	if args.happytest:
		print("happytest")
		A_G = G.automorphism_group()
		pairs_to_test = set()
		assert(min(G.degree())>1) # add dummy node to mark vertex

		def test_happy(t1):
			if t1 == min(A_G.orbit(t1)):
				H = Graph(G.edges())
				H.add_vertex(-1)
				H.add_edge(t1,-1)
				A_H = H.automorphism_group()
				for t2 in G:
					if t2 != -1 and t2 != t1 and t2 == min(A_H.orbit(t2)) and trees[t1]&trees[t2]:
						test_pair(t1,t2)
						#pair = tuple(sorted([t1,t2]))
						#if pair not in pairs_to_test: 
						#	pairs_to_test.add(pair)

		def test_pair(t1,t2):
			common_edges = trees[t1]&trees[t2]
			d = G.distance(t1,t2)
			G12 = G.subgraph(vertices=[t for t in G if common_edges.issubset(trees[t])])
			d12 = G12.distance(t1,t2)
			if d12 != d:
				print("t1",t1)
				print("t2",t2)
				with open("error.txt","a") as f:
					f.write(str(("unhappy",chi_str,t1,t2))+"\n")
				exit("found counterexample to conjecture!!")
				return False
			return True

		if args.parallel:
			result = Pool(cpu_count()).map(test_happy,N)
		else:
			result = map(test_happy,N) # single threaded
	
		if False not in result:
			print("all happy :)")

	print("")

print("all fine.")
print("diam min max",min(stat),max(stat))