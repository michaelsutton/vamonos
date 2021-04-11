
class Queue {
    constructor() {
        this.queue = [];
        this.offset = 0;
    }

    getLength() {
        return this.queue.length - this.offset;
    }
    
    isEmpty() {
        return 0 == this.queue.length;
    }
    
    enqueue(item) {
        this.queue.push(item);
    }

    dequeue() {
        if (0 != this.queue.length) {
            let item = this.queue[this.offset];
            if (2 * ++this.offset >= this.queue.length) {
                this.queue = this.queue.slice(this.offset), this.offset = 0;
            }
            return item;
        }
    }

    peek() {
        return 0 < this.queue.length ? this.queue[this.offset] : undefined;
    }
};

class Block {
    constructor(index=0, hash=0) {
        this.parents = []
        this.parent = null
        
        this.index = index
        this.hash = hash 
    
        this.blueScore = 0
        this.blueSizes = new Map()
        this.blues = new Set()
    }

    // Method used to find the selected parent by maximal blue score
    static max(block, other) {
        if (block.blueScore == other.blueScore) {
            return block.hash > other.hash ? block : other // tiebreak by max hash
        }
        return block.blueScore > other.blueScore ? block : other
    }

    // Method used to sort by blue score (thus sorting in reverse topological order)  
    static less(block, other) {
        if (block.blueScore == other.blueScore) {
            return block.hash - other.hash // tiebreak by max hash
        }
        return block.blueScore - other.blueScore
    }

    // Method to get the blue anticone size of 'this' from the worldview of 'context'
    // Expects 'this' to be ∈ blue-set(context)
    blueAnticoneSize(context) {
        let p = context
        while (p != null) {
            if (p.blueSizes.has(this)) {
                return p.blueSizes.get(this)
            }
            p = p.parent
        }
        throw new Error("Block is not blue for context")
    }

    // Method to query if 'this' is blue in the worldview of 'context'
    isBlue(context) {
        let p = context
        while (p != null) {
            if (p.blues.has(this)) {
                return true
            }
            p = p.parent
        }
        return false
    }

    // Iterate over past of 'this'
    *past() {
        let q = new Queue()
        let s = new Set()
        q.enqueue(this)
        while (!q.isEmpty()) {
            let b = q.dequeue()
            yield b
            for (const p of b.parents) {
                if (s.has(p)) {
                    continue
                }
                q.enqueue(p)
                s.add(p)
            }
        }
    }

    // Returns the merge set of 'this', that is, past(this) \ past(this.parent)
    mergeSet() {
        let s = new Set(this.past())
        s.delete(this)
        for (const block of this.parent.past()) {
            s.delete(block)
        }
        return s
    }

    // Query if 'this' is in past of 'block'
    inPast(block) {
        for (const b of block.past()) {
            if (this == b) {
                return true
            } 
        }
        return false
    }
};


class DAG {
    constructor(k, genesisHash=0) {
        this.k = k
        this.nextIndex = 0
        this.genesis = new Block(this.nextIndex++, genesisHash)
        this.blockMap = new Map()
        this.blockMap.set(this.genesis.hash, this.genesis)
    }

    addNewBlock(blockHash, parentHashes) {
        // Assert all hash conditions
        // TODO
        
        // Create new block
        let newBlock = new Block(this.nextIndex++, blockHash)

        // Add parents
        for (const parentHash of parentHashes) {
            newBlock.parents.push(this.blockMap.get(parentHash))
        }

        // Find selected parent (by maximum blue score and tie breaking by max hash)
        newBlock.parent = newBlock.parents.reduce(Block.max)

        // Add 'selected_parent' as blue block
        newBlock.blues.add(newBlock.parent)

        // Initialize 'selected_parent' blue anticone size to zero
        newBlock.blueSizes.set(newBlock.parent, 0)

        // Find selected_parent merge set
        let mergeSet = [...newBlock.mergeSet()]

        // Sort the merge set in reverse topological order
        mergeSet.sort(Block.less)

        // Iterate over the merge set and try coloring candidate blocks in blue
        candidateLoop:
            for (const blueCandidate of mergeSet) {
                let candidatePast = new Set(blueCandidate.past())
                let candidateAnticone = new Map()
                anticoneLoop:
                    for (const b of newBlock.past()) {
                        if (candidatePast.has(b)) {
                            continue anticoneLoop
                        }
                        if (b.isBlue(newBlock)) {
                            let bas = b.blueAnticoneSize(newBlock)
                            candidateAnticone.set(b, bas)
                            /* 
                            Two possible k-cluster violations here:
                                (i) The candidate blue anticone now became larger than k
                                (ii) A block in candidate's blue anticone already has k blue blocks in its own anticone
                            */
                            if (candidateAnticone.size > this.k || bas == this.k) {
                                continue candidateLoop
                            }
                        }
                    }

                // No k-cluster violation found, we can now set the candidate block as blue 
                newBlock.blues.add(blueCandidate)
                newBlock.blueSizes.set(blueCandidate, candidateAnticone.size)
                candidateAnticone.forEach(
                    (bas, bb) => newBlock.blueSizes.set(bb, bas + 1))

                if (newBlock.blues.size == this.k + 1) {
                    break
                }
            }

        // Set the blue score
        newBlock.blueScore = newBlock.parent.blueScore + newBlock.blues.size

        // Update block map
        this.blockMap.set(blockHash, newBlock)

        return newBlock
    }
};


var k = 2
var dag = new DAG(k=k, genesisHash=100)

dag.addNewBlock(101, [100])
dag.addNewBlock(102, [100])
dag.addNewBlock(103, [100])
dag.addNewBlock(104, [103])

console.log(dag.addNewBlock(105, [101, 102, 104]).blueScore)
console.log(dag.addNewBlock(106, [101]).blueScore)
console.log(dag.addNewBlock(107, [102, 104]).blueScore)
console.log(dag.addNewBlock(108, [105, 106, 107]).blueScore)



