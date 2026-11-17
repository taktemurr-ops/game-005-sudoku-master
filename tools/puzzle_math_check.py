"""Independent cross-language sanity check of Sudoku generation assumptions.
Not a replacement for running the Dart/Flutter tests.
"""
import random

def solution(seed):
    rng=random.Random(seed)
    digits=list(range(1,10));rng.shuffle(digits)
    def order():
        groups=list(range(3));rng.shuffle(groups)
        out=[]
        for g in groups:
            chunk=list(range(g*3,g*3+3));rng.shuffle(chunk);out+=chunk
        return out
    rows=order();cols=order();trans=rng.choice([True,False])
    return [[digits[((rows[c] if trans else rows[r])*3+(rows[c] if trans else rows[r])//3+(cols[r] if trans else cols[c]))%9] for c in range(9)] for r in range(9)]

def count(grid, limit=2):
    rows=[0]*9;cols=[0]*9;boxes=[0]*9
    for r in range(9):
        for c in range(9):
            d=grid[r][c]
            if not d:continue
            m=1<<d;b=r//3*3+c//3
            if (rows[r]|cols[c]|boxes[b])&m:return 0
            rows[r]|=m;cols[c]|=m;boxes[b]|=m
    seen=0
    def search():
        nonlocal seen
        if seen>=limit:return
        candidates=[]
        for r in range(9):
            for c in range(9):
                if grid[r][c]:continue
                b=r//3*3+c//3
                mask=0x3fe & ~(rows[r]|cols[c]|boxes[b])
                if not mask:return
                n=mask.bit_count()
                candidates.append((n,r,c,mask,b))
        if not candidates:
            seen+=1;return
        _,r,c,mask,b=min(candidates)
        for d in range(1,10):
            m=1<<d
            if not (mask&m):continue
            grid[r][c]=d;rows[r]|=m;cols[c]|=m;boxes[b]|=m
            search()
            grid[r][c]=0;rows[r]&=~m;cols[c]&=~m;boxes[b]&=~m
            if seen>=limit:return
    search();return seen

def main():
    difficulties={'easy':40,'medium':34,'hard':30,'expert':26,'daily':32}
    for i,(mode,target) in enumerate(difficulties.items()):
        seed=10005+i
        sol=solution(seed)
        assert count([r.copy() for r in sol])==1,mode
        puzzle=[r.copy() for r in sol]
        indices=list(range(81));random.Random(seed+100).shuffle(indices)
        for k in indices:
            if sum(d!=0 for r in puzzle for d in r)<=target:break
            r,c=divmod(k,9);old=puzzle[r][c];puzzle[r][c]=0
            if count(puzzle)!=1:puzzle[r][c]=old
        clues=sum(d!=0 for row in puzzle for d in row)
        assert count(puzzle)==1,(mode,clues)
        assert clues<81
        print(f'{mode}: {clues} clues, unique solution; valid solved grid')
    print('INDEPENDENT MATH CHECK PASS (Dart build not executed)')

if __name__=='__main__':main()
