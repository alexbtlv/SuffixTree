import Foundation

class IntReference {
    var value:Int
    init(_ value: Int) {
        self.value = value
    }
}

class StringReference {
    var value:String
    init(_ val: String) {
        self.value = val
    }
    func rangeIsValid(_ range: ClosedRange<Int>) -> Bool {
        return range.lowerBound >= 0 && range.upperBound < value.count
    }
    subscript(_ range: ClosedRange<Int>) -> String {
        get {
            assert(rangeIsValid(range) , "Index out of range")
            let strRange = convert(range: range, string: value)
            return String(value[strRange.lowerBound...strRange.upperBound])
        }
    }
    subscript(_ index: Int) -> Character? {
        get {
            if index >= 0 && index < value.count {
                return Array(value)[index]
            } else {
                return nil
            }
        }
    }
    
    func convert(range: ClosedRange<Int>, string: String) -> Range<String.Index> {
        let s = string.index(string.startIndex, offsetBy: range.lowerBound)
        let f = string.index(string.startIndex, offsetBy: range.upperBound)
        return Range(uncheckedBounds: (lower: s, upper: f))
    }
    
}

class Node {
    enum NodeType {
        case root
        case `internal`
        case leaf
    }
    
    let uuid:UUID
    var nodeType: NodeType
    var suffixTree: SuffixTree!
    var suffixLink: Node? = nil
    var suffixIndex: Int
    weak var parent: Edge? = nil
    var children:[Character:Edge] = [:]
    
    init(suffixTree:SuffixTree!, nodeType:NodeType = .leaf) {
        self.nodeType = nodeType
        self.suffixTree = suffixTree
        /*suffixIndex will be set to -1 by default and
         actual suffix index will be set later for leaves
         at the end of all phases*/
        self.suffixIndex = -1
        self.uuid = UUID()
    }
    
    func addEdgeWithNewNode(char: Character, start: Int, end: IntReference) {
        let node = Node(suffixTree: suffixTree, nodeType: .leaf)
        let edge = Edge(suffixTree: suffixTree, start: start, end: end, child: node, parent: self)
        self.children[char] = edge
    }
    
    func addEdgeWithExistingNode(char: Character, start: Int, end: IntReference, existing node: Node) {
        let edge = Edge(suffixTree: suffixTree, start: start, end: end, child: node, parent: self)
        self.children[char] = edge
    }
}

extension Node: Hashable {
    var hashValue: Int {
        return self.uuid.hashValue
    }
    
    static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}


class Edge {
    var suffixTree: SuffixTree
    var start: Int
    var end: IntReference
    var child: Node
    unowned var parent: Node
    var length:Int {
        return end.value - start + 1
    }
    var diff:Int {
        return end.value - start
    }
    
    var label:String {
        return suffixTree.corpus[start...end.value]
    }
    
    init(suffixTree: SuffixTree, start: Int, end: IntReference, child: Node, parent: Node) {
        self.suffixTree = suffixTree
        self.start = start
        self.end = end
        self.child = child
        self.parent = parent
        self.child.parent = self
    }
}

class ActivePoint {
    
    var index:Int = -1
    var length:Int
    var node:Node
    var suffixTree:SuffixTree!
    var edge:Edge? {
        guard let c = self.char else { return nil }
        guard let e = self.node.children[c] else { return nil }
        return e
    }
    var char:Character? {
        guard self.index >= 0 else { return nil }
        return suffixTree.corpus[index]
    }
    
    init(node: Node, char: Character?, length: Int) {
        self.node = node
        self.length = length
    }
    
    func nextCharDownActiveEdge(from char: Character) -> Character? {
        guard let edge = self.edge else { fatalError("Experienced a nil active Edge") }
        let corpus = suffixTree.corpus
        
        if edge.diff >= length {
            return corpus[edge.start + length]
        } else if edge.diff + 1 == length {
            if let _ = edge.child.children[char] {
                return char
            }
            return nil
        } else {
            node = edge.child
            length = length - (edge.diff + 1)
            self.index = self.index + (edge.diff + 1)
            return nextCharDownActiveEdge(from: char)
        }
    }
    
    func walkDownActiveEdge(from char: Character) -> Bool {
        guard let edge = self.edge else { fatalError("Experienced a nil active Edge") }
        
        if edge.diff < length {
            node = edge.child
            length = length - edge.diff
            if let selectEdge = node.children[char] {
                self.index = selectEdge.start
            }
            return true
        } else {
            length += 1
        }
        return false
    }
}

class SuffixTree {
    
    let corpus: StringReference
    let root: Node
    let globalEnd: IntReference
    var remainder: Int
    let active: ActivePoint
    
    init(with corpus: String) {
        self.corpus = StringReference(corpus)
        let rootNode = Node(suffixTree: nil, nodeType: .root)
        self.root = rootNode
        self.globalEnd = IntReference(-1)
        self.remainder = 0
        self.active = ActivePoint(node: rootNode, char: nil, length: 0)
        self.active.suffixTree = self
        self.root.suffixTree = self
        buildTree()
        setSuffixIndexByDFS(node: rootNode, labelHeight: 0)
    }
    
    private func buildTree() {
        for (i,char) in self.corpus.value.enumerated() {
            performPhase(i: i, char: char)
        }
    }
    
    private func performPhase(i:Int, char:Character) {
        var lastInternalNode: Node? = nil
        globalEnd.value += 1
        remainder += 1
        
        while remainder > 0 {
            if active.length == 0 {
                if let existingEdge = root.children[char] {
                    active.index = existingEdge.start
                    active.length += 1
                    break
                } else {
                    root.addEdgeWithNewNode(char: char, start: i, end: globalEnd)
                    remainder -= 1
                }
            } else {
                if let nextChar = active.nextCharDownActiveEdge(from: char) {
                    if char == nextChar {
                        let walkedDown = active.walkDownActiveEdge(from: char)
                        if walkedDown {
                            lastInternalNode?.suffixLink = active.edge?.child
                        }
                        break
                    } else {
                        guard let activeEdge = active.edge else { fatalError("Experienced a nil active Edge") }
                        let oldEnd = activeEdge.end
                        activeEdge.end = IntReference(activeEdge.start + active.length - 1)
                        let newInternalNode = Node(suffixTree: self, nodeType: .internal)
                        newInternalNode.addEdgeWithExistingNode(char: corpus[activeEdge.start + active.length] ?? Character(""), start: activeEdge.start + active.length, end: oldEnd, existing: activeEdge.child)
                        newInternalNode.addEdgeWithNewNode(char: corpus[i] ?? Character(""), start: i, end: globalEnd)
                        activeEdge.child = newInternalNode
                        newInternalNode.parent = activeEdge
                        newInternalNode.suffixLink = root
                        lastInternalNode?.suffixLink = newInternalNode
                        lastInternalNode = newInternalNode
                        suffixLinkCheck()
                    }
                } else {
                    if let activeEdge = active.edge {
                        activeEdge.child.addEdgeWithNewNode(char: char, start: i, end: globalEnd)
                        suffixLinkCheck()
                    }
                }
            }
        }
    }
    
    func suffixLinkCheck() {
        if active.node != root {
            if let sufLink = active.node.suffixLink {
                active.node = sufLink
            } else {
                active.node = root
            }
        } else {
            active.index += 1
            active.length -= 1
        }
        remainder -= 1
    }
    
    func setSuffixIndexByDFS(node n: Node?, labelHeight: Int) {
        guard let n = n else { return }
        
        if n.nodeType != .root {
            // print label
        }
        
        for (_, edge) in n.children {
            setSuffixIndexByDFS(node: edge.child, labelHeight: labelHeight + edge.length)
        }
        
        if n.nodeType == .leaf {
            n.suffixIndex = globalEnd.value - labelHeight + 1
        }
    }
}

let t = SuffixTree(with: "xabxa#babxba$")



for (k, v) in t.root.children {
    print(k, v.label)
}

let firstChild = t.root.children.first { (k,v) -> Bool in
    k == "b"
}
let secondChild = firstChild?.value.child.children.first(where: { (k,v) -> Bool in
    k == "x"
})
let thirdChild = secondChild?.value.child.children.first(where: { (k,v) -> Bool in
    k == "b"
})
print(thirdChild?.value.child.suffixIndex)






