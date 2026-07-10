import SwiftUI
import CoreGraphics
import Combine

@MainActor
class PathfindingViewModel: ObservableObject {
    @Published var graph: Graph?
    @Published var currentGraphSize: GraphSize?
    @Published var currentAlgorithm: PathfindingAlgorithm?
    @Published var startNode: UUID?
    @Published var targetNode: UUID?
    @Published var nodeStatuses: [UUID: NodeStatus] = [:]
    @Published var finalPath: [UUID] = []
    @Published var isGenerating = false
    @Published var isRunning = false
    @Published var metrics: PathfindingMetrics?
    @Published var boundingBox: CGRect = .zero

    func generateGraph(size: GraphSize) {
        isGenerating = true
        graph = nil
        nodeStatuses.removeAll()
        finalPath.removeAll()
        metrics = nil
        currentGraphSize = size

        DispatchQueue.global(qos: .userInitiated).async {
            let (newGraph, newStart, newTarget, box) = createRandomGraph(size: size)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.graph = newGraph
                self.startNode = newStart
                self.targetNode = newTarget
                self.boundingBox = box
                self.nodeStatuses[newStart] = .start
                self.nodeStatuses[newTarget] = .target
                self.isGenerating = false
            }
        }
    }

    func runAlgorithm(_ type: PathfindingAlgorithm) {
        guard let graph = graph, let start = startNode, let target = targetNode else { return }

        currentAlgorithm = type
        isRunning = true
        metrics = nil
        finalPath.removeAll()
        nodeStatuses = [start: .start, target: .target]

        Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            let delay: UInt64 = 1_000_000

            let onUpdate: PathfindingAlgorithms.UpdateCallback = { @MainActor [weak self] id, status in
                guard let self = self else { return }
                if id != start && id != target {
                    self.nodeStatuses[id] = status
                }
            }

            let result: PathfindingResult

            switch type {
            case .bfs:    result = await PathfindingAlgorithms.runBFS(graph: graph, start: start, target: target, delay: delay, onUpdate: onUpdate)
            case .dfs:    result = await PathfindingAlgorithms.runDFS(graph: graph, start: start, target: target, delay: delay, onUpdate: onUpdate)
            case .ucs:    result = await PathfindingAlgorithms.runUCS(graph: graph, start: start, target: target, delay: delay, onUpdate: onUpdate)
            case .ids:    result = await PathfindingAlgorithms.runIDS(graph: graph, start: start, target: target, delay: delay, onUpdate: onUpdate)
            case .greedy: result = await PathfindingAlgorithms.runGreedy(graph: graph, start: start, target: target, delay: delay, onUpdate: onUpdate)
            case .astar:  result = await PathfindingAlgorithms.runAStar(graph: graph, start: start, target: target, delay: delay, onUpdate: onUpdate)
            }

            let endTime = CFAbsoluteTimeGetCurrent()

            // Animate the final path — all nodes go into finalPath for the yellow trace,
            // but only intermediate nodes change color (start/target keep green/red)
            if !result.path.isEmpty {
                for nodeId in result.path {
                    finalPath.append(nodeId)
                    if nodeId != start && nodeId != target {
                        nodeStatuses[nodeId] = .path
                        try? await Task.sleep(nanoseconds: 5_000_000)
                    }
                }
            }

            self.metrics = PathfindingMetrics(
                algorithmName: type.rawValue,
                totalNodes: graph.nodes.count,
                timeTakenMS: (endTime - startTime) * 1000.0,
                exploredNodesCount: result.exploredCount,
                memoryUsedBytes: result.peakMemoryBytes,
                stepsTaken: result.exploredCount,
                uniqueExploredCount: result.uniqueExploredCount
            )

            self.isRunning = false
            self.currentAlgorithm = nil
        }
    }

    func resetVisualization() {
        guard graph != nil else { return }
        finalPath.removeAll()
        nodeStatuses.removeAll()
        if let s = startNode  { nodeStatuses[s] = .start }
        if let t = targetNode { nodeStatuses[t] = .target }
    }
}
