//
//  Models.swift
//  AIProjectino
//
//  Created by Crescenzo Di Franco on 09/07/2026.
//

import Foundation
import CoreGraphics

enum NodeStatus: Equatable {
    case unvisited
    case open
    case closed
    case path
    case start
    case target
}
// MARK: Nodi
struct Node: Identifiable, Hashable {
    let id: UUID
    var position: CGPoint
    
    init(id: UUID = UUID(), position: CGPoint) {
        self.id = id
        self.position = position
    }
}

struct Edge: Identifiable, Hashable {
    let id: UUID
    let source: UUID
    let target: UUID
    let weight: Double
    
    init(id: UUID = UUID(), source: UUID, target: UUID, weight: Double) {
        self.id = id
        self.source = source
        self.target = target
        self.weight = weight
    }
}

// lista di adiacenza e vicini del nodo
struct Graph {
    var nodes: [UUID: Node] = [:]
    var edges: [Edge] = []
    var adjacencyList: [UUID: [Edge]] = [:]
    
    mutating func addNode(_ node: Node) {
        nodes[node.id] = node
        if adjacencyList[node.id] == nil {
            adjacencyList[node.id] = []
        }
    }
    
    mutating func addEdge(_ edge: Edge, bidirectional: Bool = true) {
        edges.append(edge)
        adjacencyList[edge.source]?.append(edge)
        
        if bidirectional {
            let reverseEdge = Edge(id: UUID(), source: edge.target, target: edge.source, weight: edge.weight)
            edges.append(reverseEdge)
            adjacencyList[edge.target]?.append(reverseEdge)
        }
    }
}

// Cambia in nomi brother
enum GraphSize: String, CaseIterable {
    case small = "100"
    case medium = "1.000"
    case gigantomassive = "10.000"
    case ultraMassive = "100.000"
    
    var nodeCount: Int {
        switch self {
        case .small: return 100
        case .medium: return 1000
        case .gigantomassive: return 10000
        case .ultraMassive: return 100000
        }
    }
    
    var connectionRadius: Double {
        switch self {
        case .small: return 150.0
        case .medium: return 150.0
        case .gigantomassive: return 150.0
        case .ultraMassive: return 150.0
        }
    }
}

struct PathfindingMetrics: Identifiable {
    // non so perche ma senza ID non funziona, grazie Swift, fixare
    let id = UUID()

    let algorithmName: String
    let totalNodes: Int
    let timeTakenMS: Double
    let exploredNodesCount: Int
    let memoryUsedBytes: Int64

    let stepsTaken: Int
    let uniqueExploredCount: Int
    let pathLength: Int
    let pathCost: Double

    var memoryUsedFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: memoryUsedBytes)
    }

    var timeFormatted: String {
        let timeInSeconds = timeTakenMS / 1000.0
        if timeInSeconds < 60 {
            return String(format: "%.2f ms", timeTakenMS)
        } else {
            let m = Int(timeInSeconds) / 60
            let s = timeInSeconds.truncatingRemainder(dividingBy: 60)
            return String(format: "%dm %.1fs", m, s)
        }
    }
}
