
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
    
        this.blue_score = 0
        this.blue_sizes = new Map()
        this.blues = new Set()
    }

    // Method used to find the selected parent by maximal blue score
    static max(block, other) {
        if (block.blue_score == other.blue_score) {
            return block.hash > other.hash ? block : other // tiebreak by max hash
        }
        return block.blue_score > other.blue_score ? block : other
    }

    // Method used to sort by blue score (thus sorting in reverse topological order)  
    static less(block, other) {
        if (block.blue_score == other.blue_score) {
            return block.hash - other.hash // tiebreak by max hash
        }
        return block.blue_score - other.blue_score
    }

    // Method to get the blue anticone size of 'this' from the worldview of 'context'
    // Expects 'this' to be ∈ blue-set(context)
    blue_anticone_size(context) {
        let p = context
        while (p != null) {
            if (p.blue_sizes.has(this)) {
                return p.blue_sizes.get(this)
            }
            p = p.parent
        }
        throw new Error("Block is not blue for context")
    }

    // Method to query if 'this' is blue in the worldview of 'context'
    is_blue(context) {
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
    merge_set() {
        let s = new Set(this.past())
        s.delete(this)
        for (const block of this.parent.past()) {
            s.delete(block)
        }
        return s
    }

    // Query if 'this' is in past of 'block'
    in_past(block) {
        for (const b of block.past()) {
            if (this == b) {
                return true
            } 
        }
        return false
    }
};


class DAG {
    constructor(k, genesis_hash=0) {
        this.k = k
        this.next_index = 0
        this.genesis = new Block(this.next_index++, genesis_hash)
        this.block_map = new Map()
        this.block_map.set(this.genesis.hash, this.genesis)
    }

    add_new_block(block_hash, parent_hashes) {
        // Assert all hash conditions
        // TODO
        
        // Create new block
        let new_block = new Block(this.next_index++, block_hash)

        // Add parents
        for (const parent_hash of parent_hashes) {
            new_block.parents.push(this.block_map.get(parent_hash))
        }

        // Find selected parent (by maximum blue score and tie breaking by max hash)
        new_block.parent = new_block.parents.reduce(Block.max)

        // Add 'selected_parent' as blue block
        new_block.blues.add(new_block.parent)

        // Initialize 'selected_parent' blue anticone size to zero
        new_block.blue_sizes.set(new_block.parent, 0)

        // Find selected_parent merge set
        let merge_set = [...new_block.merge_set()]

        // Sort the merge set in reverse topological order
        merge_set.sort(Block.less)

        // Iterate over the merge set and try coloring candidate blocks in blue
        candidate_loop:
            for (const blue_candidate of merge_set) {
                let candidate_past = new Set(blue_candidate.past())
                let candidate_anticone = new Map()
                anticone_loop:
                    for (const b of new_block.past()) {
                        if (candidate_past.has(b)) {
                            continue anticone_loop
                        }
                        if (b.is_blue(new_block)) {
                            let bas = b.blue_anticone_size(new_block)
                            candidate_anticone.set(b, bas)
                            /* 
                            Two possible k-cluster violations here:
                                (i) The candidate blue anticone now became larger than k
                                (ii) A block in candidate's blue anticone already has k blue blocks in its own anticone
                            */
                            if (candidate_anticone.size > this.k || bas == this.k) {
                                continue candidate_loop
                            }
                        }
                    }

                // No k-cluster violation found, we can now set the candidate block as blue 
                new_block.blues.add(blue_candidate)
                new_block.blue_sizes.set(blue_candidate, candidate_anticone.size)
                candidate_anticone.forEach(
                    (bas, bb) => new_block.blue_sizes.set(bb, bas + 1))

                if (new_block.blues.size == this.k + 1) {
                    break
                }
            }

        new_block.blue_score = new_block.parent.blue_score + new_block.blues.size

        this.block_map.set(block_hash, new_block)

        return new_block
    }
};


var k = 2
var dag = new DAG(k=k, genesis_hash=100)

dag.add_new_block(101, [100])
dag.add_new_block(102, [100])
dag.add_new_block(103, [100])
dag.add_new_block(104, [103])

console.log(dag.add_new_block(105, [101, 102, 104]).blue_score)
console.log(dag.add_new_block(106, [101]).blue_score)
console.log(dag.add_new_block(107, [102, 104]).blue_score)
console.log(dag.add_new_block(108, [105, 106, 107]).blue_score)



