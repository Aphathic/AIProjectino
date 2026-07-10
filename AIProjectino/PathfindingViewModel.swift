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
    @Published var isAnimating = false
    @Published var metrics: PathfindingMetrics?
    @Published var boundingBox: CGRect = .zero
    @Published var elapsedTime: TimeInterval = 0
    @Published var algorithmError: String?
    
    var formattedElapsedTime: String {
        if elapsedTime < 60 {
            return String(format: "%.1fs", elapsedTime)
        } else {
            let m = Int(elapsedTime) / 60
            let s = elapsedTime.truncatingRemainder(dividingBy: 60)
            return String(format: "%dm %.1fs", m, s)
        }
    }
    
    private var currentTask: Task<Void, Never>?
    private var timerCancellable: AnyCancellable?
    private var algorithmStartTime: CFAbsoluteTime = 0

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

    func stopAlgorithm() {
        currentTask?.cancel()
        stopTimer()
        isRunning = false
        isAnimating = false
        currentAlgorithm = nil
    }
    
    private func startTimer() {
        algorithmStartTime = CFAbsoluteTimeGetCurrent()
        elapsedTime = 0
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.elapsedTime = CFAbsoluteTimeGetCurrent() - self.algorithmStartTime
            }
    }
    
    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func runAlgorithm(_ type: PathfindingAlgorithm) {
        guard let graph = graph, let start = startNode, let target = targetNode else { return }

        currentAlgorithm = type
        isRunning = true
        isAnimating = false
        metrics = nil
        algorithmError = nil
        finalPath.removeAll()
        nodeStatuses = [start: .start, target: .target]
        
        currentTask?.cancel()
        startTimer()

        currentTask = Task {
            // ── Phase 1: Compute at full speed ──────────────────────
            let startTime = CFAbsoluteTimeGetCurrent()

            let result = await Self.computeAlgorithm(type: type, graph: graph, start: start, target: target)

            let endTime = CFAbsoluteTimeGetCurrent()
            self.stopTimer()
            
            if Task.isCancelled { return }
            
            // ── Phase 2: Trace the final path instantly ─────────────
            self.isAnimating = true
            
            if !result.path.isEmpty {
                finalPath = result.path
                for nodeId in result.path {
                    if nodeId != start && nodeId != target {
                        nodeStatuses[nodeId] = .path
                    }
                }
            } else {
                self.algorithmError = "No path found between start and target nodes."
            }

            // ── Phase 4: Show results ───────────────────────────────
            self.metrics = PathfindingMetrics(
                algorithmName: type.rawValue,
                totalNodes: graph.nodes.count,
                timeTakenMS: (endTime - startTime) * 1000.0,
                exploredNodesCount: result.exploredCount,
                memoryUsedBytes: result.peakMemoryBytes,
                stepsTaken: result.exploredCount,
                uniqueExploredCount: result.uniqueExploredCount,
                pathLength: result.path.count
            )

            self.isRunning = false
            self.isAnimating = false
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
    
    // Runs on a background executor but automatically inherits Task cancellation from the parent Task!
    nonisolated static func computeAlgorithm(type: PathfindingAlgorithm, graph: Graph, start: UUID, target: UUID) async -> PathfindingResult {
        let onUpdate: PathfindingAlgorithms.UpdateCallback = { _, _ in }
        switch type {
        case .bfs:    return await PathfindingAlgorithms.runBFS(graph: graph, start: start, target: target, delay: 0, onUpdate: onUpdate)
        case .dfs:    return await PathfindingAlgorithms.runDFS(graph: graph, start: start, target: target, delay: 0, onUpdate: onUpdate)
        case .greedy: return await PathfindingAlgorithms.runGreedy(graph: graph, start: start, target: target, delay: 0, onUpdate: onUpdate)
        case .astar:  return await PathfindingAlgorithms.runAStar(graph: graph, start: start, target: target, delay: 0, onUpdate: onUpdate)
        }
    }
}
