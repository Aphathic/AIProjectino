import Foundation
import CoreGraphics

/// Generates a random geometric graph using spatial hashing for efficient neighbor lookup.
/// Runs off the main thread — no SwiftUI imports to avoid implicit MainActor isolation.
func createRandomGraph(size: GraphSize) -> (Graph, UUID, UUID, CGRect) {
    var graph = Graph()
    let count = size.nodeCount
    let radius = size.connectionRadius

    let areaSize: Double
    switch size {
    case .small:            areaSize = 1_000
    case .medium:           areaSize = 3_000
    case .gigantomassive:   areaSize = 10_000
    }

    var minX: Double =  .greatestFiniteMagnitude
    var minY: Double =  .greatestFiniteMagnitude
    var maxX: Double = -.greatestFiniteMagnitude
    var maxY: Double = -.greatestFiniteMagnitude

    // 1. Place nodes randomly
    var nodesArray = [Node]()
    nodesArray.reserveCapacity(count)

    for _ in 0..<count {
        let x = Double.random(in: 0...areaSize)
        let y = Double.random(in: 0...areaSize)
        minX = min(minX, x); minY = min(minY, y)
        maxX = max(maxX, x); maxY = max(maxY, y)

        let node = Node(position: CGPoint(x: x, y: y))
        graph.addNode(node)
        nodesArray.append(node)
    }

    // 2. Build a spatial hash grid (cell size = connection radius)
    let cellSize = radius
    var grid = [String: [Node]]()

    func cellKey(_ x: Double, _ y: Double) -> String {
        "\(Int(x / cellSize)),\(Int(y / cellSize))"
    }

    for node in nodesArray {
        grid[cellKey(node.position.x, node.position.y), default: []].append(node)
    }

    let neighborOffsets = [
        (0,0), (-1,-1), (-1,0), (-1,1),
        (0,-1), (0,1), (1,-1), (1,0), (1,1)
    ]

    // 3. Connect nodes within radius using spatial hashing
    for node in nodesArray {
        let cx = Int(node.position.x / cellSize)
        let cy = Int(node.position.y / cellSize)

        var potentialNeighbors: [(Node, Double)] = []

        for offset in neighborOffsets {
            let key = "\(cx + offset.0),\(cy + offset.1)"
            guard let bucket = grid[key] else { continue }
            for neighbor in bucket where node.id != neighbor.id {
                let dist = PathfindingAlgorithms.heuristic(nodeA: node, nodeB: neighbor)
                if dist <= radius {
                    potentialNeighbors.append((neighbor, dist))
                }
            }
        }
        
        potentialNeighbors.sort { $0.1 < $1.1 }
        
        for (neighbor, dist) in potentialNeighbors {
            let degreeA = graph.adjacencyList[node.id]?.count ?? 0
            if degreeA >= 8 { break }
            
            let degreeB = graph.adjacencyList[neighbor.id]?.count ?? 0
            if degreeB >= 8 { continue }
            
            let alreadyConnected = graph.adjacencyList[node.id]?.contains(where: { $0.target == neighbor.id }) ?? false
            if !alreadyConnected {
                graph.addEdge(Edge(source: node.id, target: neighbor.id, weight: dist), bidirectional: true)
            }
        }
    }

    // 4. Ensure every node has at least 2 connections
    for node in nodesArray {
        var degreeA = graph.adjacencyList[node.id]?.count ?? 0
        while degreeA < 2 {
            var nearest: Node?
            var bestDist: Double = .greatestFiniteMagnitude
            var fallbackNearest: Node?
            var fallbackBestDist: Double = .greatestFiniteMagnitude
            
            for other in nodesArray where other.id != node.id {
                let alreadyConnected = graph.adjacencyList[node.id]?.contains(where: { $0.target == other.id }) ?? false
                if !alreadyConnected {
                    let dist = PathfindingAlgorithms.heuristic(nodeA: node, nodeB: other)
                    
                    let degreeB = graph.adjacencyList[other.id]?.count ?? 0
                    if degreeB < 8 {
                        if dist < bestDist {
                            bestDist = dist
                            nearest = other
                        }
                    }
                    if dist < fallbackBestDist {
                        fallbackBestDist = dist
                        fallbackNearest = other
                    }
                }
            }
            
            if let target = nearest ?? fallbackNearest {
                let dist = nearest != nil ? bestDist : fallbackBestDist
                graph.addEdge(Edge(source: node.id, target: target.id, weight: dist), bidirectional: true)
                degreeA += 1
            } else {
                break
            }
        }
    }

    // 5. Pick start and target
    let start = nodesArray.randomElement()!.id
    var target = nodesArray.randomElement()!.id
    while target == start { target = nodesArray.randomElement()!.id }

    let padding: Double = 50
    let box = CGRect(
        x: minX - padding, y: minY - padding,
        width: (maxX - minX) + padding * 2,
        height: (maxY - minY) + padding * 2
    )

    return (graph, start, target, box)
}
