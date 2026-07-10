import Foundation

enum PathfindingAlgorithm: String, CaseIterable, Identifiable {
    case bfs = "BFS"
    case dfs = "DFS"
    case ucs = "UCS (Dijkstra)"
    case ids = "Iterative Deepening"
    case greedy = "Greedy Search"
    case astar = "A* Search"

    var id: String { self.rawValue }
}

struct PathfindingResult {
    let path: [UUID]
    /// Total steps / nodes popped from frontier (may include revisits depending on algorithm)
    let exploredCount: Int
    /// Unique nodes discovered/explored (size of visited / costSoFar sets)
    let uniqueExploredCount: Int
    let peakMemoryBytes: Int64
}

class PathfindingAlgorithms {
    typealias UpdateCallback = (UUID, NodeStatus) async -> Void
    
    // Memory approximation based on capacities to represent theoretical space complexity
    private static func calcMem(queue: Int = 0, visited: Int = 0, cameFrom: Int = 0, pq: Int = 0, costSoFar: Int = 0) -> Int64 {
        return Int64(queue * 16 + visited * 16 + cameFrom * 32 + pq * 24 + costSoFar * 24)
    }
    
    // MARK: - BFS
    static func runBFS(graph: Graph, start: UUID, target: UUID, delay: UInt64, onUpdate: @escaping UpdateCallback) async -> PathfindingResult {
        var queue = [start]
        var visited = Set<UUID>([start])
        var cameFrom = [UUID: UUID]()
        var exploredCount = 0
        var closedSet = Set<UUID>()
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            exploredCount += 1
            closedSet.insert(current)
            
            if current != start && current != target {
                await onUpdate(current, .closed)
                if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            }
            
            if current == target {
                let mem = calcMem(queue: queue.capacity, visited: visited.capacity, cameFrom: cameFrom.capacity)
                return PathfindingResult(path: reconstructPath(cameFrom: cameFrom, current: target), exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
            }
            
            for edge in graph.adjacencyList[current] ?? [] {
                let neighbor = edge.target
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    cameFrom[neighbor] = current
                    queue.append(neighbor)
                    
                    if neighbor != start && neighbor != target {
                        await onUpdate(neighbor, .open)
                    }
                }
            }
        }
        
        let mem = calcMem(queue: queue.capacity, visited: visited.capacity, cameFrom: cameFrom.capacity)
        return PathfindingResult(path: [], exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
    }
    
    // MARK: - DFS
    static func runDFS(graph: Graph, start: UUID, target: UUID, delay: UInt64, onUpdate: @escaping UpdateCallback) async -> PathfindingResult {
        var stack = [start]
        var visited = Set<UUID>([start])
        var cameFrom = [UUID: UUID]()
        var exploredCount = 0
        var closedSet = Set<UUID>()
        
        while !stack.isEmpty {
            let current = stack.removeLast()
            exploredCount += 1
            closedSet.insert(current)
            
            if current != start && current != target {
                await onUpdate(current, .closed)
                if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            }
            
            if current == target {
                let mem = calcMem(queue: stack.capacity, visited: visited.capacity, cameFrom: cameFrom.capacity)
                return PathfindingResult(path: reconstructPath(cameFrom: cameFrom, current: target), exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
            }
            
            for edge in (graph.adjacencyList[current] ?? []).reversed() {
                let neighbor = edge.target
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    cameFrom[neighbor] = current
                    stack.append(neighbor)
                    
                    if neighbor != start && neighbor != target {
                        await onUpdate(neighbor, .open)
                    }
                }
            }
        }
        
        let mem = calcMem(queue: stack.capacity, visited: visited.capacity, cameFrom: cameFrom.capacity)
        return PathfindingResult(path: [], exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
    }
    
    // MARK: - PriorityQueue for UCS, Greedy, A*
    struct PQElement<T>: Comparable {
        let element: T
        let priority: Double
        
        static func < (lhs: PQElement, rhs: PQElement) -> Bool {
            return lhs.priority < rhs.priority
        }
        static func == (lhs: PQElement, rhs: PQElement) -> Bool {
            return lhs.priority == rhs.priority
        }
    }
    
    struct Heap<Element: Comparable> {
        var elements: [Element] = []
        let sort: (Element, Element) -> Bool
        
        init(sort: @escaping (Element, Element) -> Bool) {
            self.sort = sort
        }
        
        var isEmpty: Bool { elements.isEmpty }
        
        mutating func insert(_ element: Element) {
            elements.append(element)
            siftUp(from: elements.count - 1)
        }
        
        mutating func remove() -> Element? {
            guard !isEmpty else { return nil }
            if elements.count == 1 { return elements.removeLast() }
            let value = elements[0]
            elements[0] = elements.removeLast()
            siftDown(from: 0)
            return value
        }
        
        private mutating func siftUp(from index: Int) {
            var child = index
            var parent = (child - 1) / 2
            while child > 0 && sort(elements[child], elements[parent]) {
                elements.swapAt(child, parent)
                child = parent
                parent = (child - 1) / 2
            }
        }
        
        private mutating func siftDown(from index: Int) {
            var parent = index
            while true {
                let left = parent * 2 + 1
                let right = left + 1
                var candidate = parent
                if left < elements.count && sort(elements[left], elements[candidate]) {
                    candidate = left
                }
                if right < elements.count && sort(elements[right], elements[candidate]) {
                    candidate = right
                }
                if candidate == parent { return }
                elements.swapAt(parent, candidate)
                parent = candidate
            }
        }
    }

    // MARK: - UCS (Dijkstra)
    static func runUCS(graph: Graph, start: UUID, target: UUID, delay: UInt64, onUpdate: @escaping UpdateCallback) async -> PathfindingResult {
        var pq = Heap<PQElement<UUID>>(sort: <)
        pq.insert(PQElement(element: start, priority: 0))
        var costSoFar = [UUID: Double]()
        costSoFar[start] = 0
        var cameFrom = [UUID: UUID]()
        var exploredCount = 0
        var closedSet = Set<UUID>()
        
        while let currentPQ = pq.remove() {
            let current = currentPQ.element
            
            if let cost = costSoFar[current], cost < currentPQ.priority { continue }
            
            exploredCount += 1
            closedSet.insert(current)
            
            if current != start && current != target {
                await onUpdate(current, .closed)
                if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            }
            
            if current == target {
                let mem = calcMem(cameFrom: cameFrom.capacity, pq: pq.elements.capacity, costSoFar: costSoFar.capacity)
                return PathfindingResult(path: reconstructPath(cameFrom: cameFrom, current: target), exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
            }
            
            for edge in graph.adjacencyList[current] ?? [] {
                let neighbor = edge.target
                let newCost = (costSoFar[current] ?? 0) + edge.weight
                
                if costSoFar[neighbor] == nil || newCost < costSoFar[neighbor]! {
                    costSoFar[neighbor] = newCost
                    cameFrom[neighbor] = current
                    pq.insert(PQElement(element: neighbor, priority: newCost))
                    
                    if neighbor != start && neighbor != target {
                        await onUpdate(neighbor, .open)
                    }
                }
            }
        }
        
        let mem = calcMem(cameFrom: cameFrom.capacity, pq: pq.elements.capacity, costSoFar: costSoFar.capacity)
        return PathfindingResult(path: [], exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
    }
    
    // MARK: - Heuristic (Euclidean Distance)
    static func heuristic(nodeA: Node?, nodeB: Node?) -> Double {
        guard let a = nodeA, let b = nodeB else { return 0 }
        let dx = a.position.x - b.position.x
        let dy = a.position.y - b.position.y
        return sqrt(dx*dx + dy*dy)
    }

    // MARK: - A* Search
    static func runAStar(graph: Graph, start: UUID, target: UUID, delay: UInt64, onUpdate: @escaping UpdateCallback) async -> PathfindingResult {
        var pq = Heap<PQElement<UUID>>(sort: <)
        pq.insert(PQElement(element: start, priority: 0))
        var costSoFar = [UUID: Double]()
        costSoFar[start] = 0
        var cameFrom = [UUID: UUID]()
        var exploredCount = 0
        var closedSet = Set<UUID>()
        
        let targetNode = graph.nodes[target]
        
        while let currentPQ = pq.remove() {
            let current = currentPQ.element
            if let cost = costSoFar[current], cost + heuristic(nodeA: graph.nodes[current], nodeB: targetNode) < currentPQ.priority { continue }
            
            exploredCount += 1
            closedSet.insert(current)
            
            if current != start && current != target {
                await onUpdate(current, .closed)
                if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            }
            
            if current == target {
                let mem = calcMem(cameFrom: cameFrom.capacity, pq: pq.elements.capacity, costSoFar: costSoFar.capacity)
                return PathfindingResult(path: reconstructPath(cameFrom: cameFrom, current: target), exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
            }
            
            for edge in graph.adjacencyList[current] ?? [] {
                let neighbor = edge.target
                let newCost = (costSoFar[current] ?? 0) + edge.weight
                
                if costSoFar[neighbor] == nil || newCost < costSoFar[neighbor]! {
                    costSoFar[neighbor] = newCost
                    let priority = newCost + heuristic(nodeA: graph.nodes[neighbor], nodeB: targetNode)
                    cameFrom[neighbor] = current
                    pq.insert(PQElement(element: neighbor, priority: priority))
                    
                    if neighbor != start && neighbor != target {
                        await onUpdate(neighbor, .open)
                    }
                }
            }
        }
        
        let mem = calcMem(cameFrom: cameFrom.capacity, pq: pq.elements.capacity, costSoFar: costSoFar.capacity)
        return PathfindingResult(path: [], exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
    }
    
    // MARK: - Greedy Search
    static func runGreedy(graph: Graph, start: UUID, target: UUID, delay: UInt64, onUpdate: @escaping UpdateCallback) async -> PathfindingResult {
        var pq = Heap<PQElement<UUID>>(sort: <)
        pq.insert(PQElement(element: start, priority: 0))
        var visited = Set<UUID>([start])
        var cameFrom = [UUID: UUID]()
        var exploredCount = 0
        var closedSet = Set<UUID>()
        
        let targetNode = graph.nodes[target]
        
        while let currentPQ = pq.remove() {
            let current = currentPQ.element
            exploredCount += 1
            closedSet.insert(current)
            
            if current != start && current != target {
                await onUpdate(current, .closed)
                if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            }
            
            if current == target {
                let mem = calcMem(visited: visited.capacity, cameFrom: cameFrom.capacity, pq: pq.elements.capacity)
                return PathfindingResult(path: reconstructPath(cameFrom: cameFrom, current: target), exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
            }
            
            for edge in graph.adjacencyList[current] ?? [] {
                let neighbor = edge.target
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    cameFrom[neighbor] = current
                    let priority = heuristic(nodeA: graph.nodes[neighbor], nodeB: targetNode)
                    pq.insert(PQElement(element: neighbor, priority: priority))
                    
                    if neighbor != start && neighbor != target {
                        await onUpdate(neighbor, .open)
                    }
                }
            }
        }
        
        let mem = calcMem(visited: visited.capacity, cameFrom: cameFrom.capacity, pq: pq.elements.capacity)
        return PathfindingResult(path: [], exploredCount: exploredCount, uniqueExploredCount: closedSet.count, peakMemoryBytes: mem)
    }

    class ClosedSetTracker {
        var nodes = Set<UUID>()
    }

    // MARK: - IDS (Iterative Deepening Search)
    static func runIDS(graph: Graph, start: UUID, target: UUID, delay: UInt64, onUpdate: @escaping UpdateCallback) async -> PathfindingResult {
        var maxDepth = 0
        var totalExplored = 0
        let tracker = ClosedSetTracker()
        
        while true {
            let (path, found, exploredCount) = await dls(graph: graph, node: start, target: target, depth: maxDepth, cameFrom: [:], delay: delay, onUpdate: onUpdate, tracker: tracker)
            totalExplored += exploredCount
            
            if found {
                // Peak memory for IDS is essentially maxDepth * stack frame size.
                // We'll estimate each stack frame uses roughly 256 bytes in Swift.
                let mem = Int64(maxDepth * 256)
                return PathfindingResult(path: path, exploredCount: totalExplored, uniqueExploredCount: tracker.nodes.count, peakMemoryBytes: mem)
            }
            
            if maxDepth > graph.nodes.count {
                break
            }
            maxDepth += 1
        }
        
        let mem = Int64(maxDepth * 256)
        return PathfindingResult(path: [], exploredCount: totalExplored, uniqueExploredCount: tracker.nodes.count, peakMemoryBytes: mem)
    }
    
    private static func dls(graph: Graph, node: UUID, target: UUID, depth: Int, cameFrom: [UUID: UUID], delay: UInt64, onUpdate: @escaping UpdateCallback, tracker: ClosedSetTracker) async -> ([UUID], Bool, Int) {
        if depth == 0 {
            if node == target {
                return (reconstructPath(cameFrom: cameFrom, current: target), true, 1)
            } else {
                return ([], false, 1)
            }
        } else if depth > 0 {
            var exploredCount = 1
            tracker.nodes.insert(node)
            
            if node != target {
                await onUpdate(node, .closed)
                if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            }
            
            for edge in graph.adjacencyList[node] ?? [] {
                let neighbor = edge.target
                var newCameFrom = cameFrom
                newCameFrom[neighbor] = node
                
                await onUpdate(neighbor, .open)
                
                let (path, found, childExplored) = await dls(graph: graph, node: neighbor, target: target, depth: depth - 1, cameFrom: newCameFrom, delay: delay, onUpdate: onUpdate, tracker: tracker)
                exploredCount += childExplored
                
                if found {
                    return (path, true, exploredCount)
                }
            }
            return ([], false, exploredCount)
        }
        
        return ([], false, 0)
    }
    
    // MARK: - Helper
    private static func reconstructPath(cameFrom: [UUID: UUID], current: UUID) -> [UUID] {
        var path = [current]
        var current = current
        while let previous = cameFrom[current] {
            path.append(previous)
            current = previous
        }
        return path.reversed()
    }
}
