import SwiftUI

// Central color mapping used by the Canvas
fileprivate func colorForStatus(_ status: NodeStatus) -> Color {
    switch status {
    case .unvisited: return Color.gray.opacity(0.25)
    case .open: return Color.cyan
    case .closed: return Color.blue
    case .path: return Color.yellow
    case .start: return Color.green
    case .target: return Color.red
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PathfindingViewModel()

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Main Canvas Area
                ZStack {
                    if viewModel.graph != nil {
                        ZoomableScrollView(minimumZoomScale: 1.0, maximumZoomScale: 8.0) {
                            GraphCanvasView(viewModel: viewModel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyCanvasView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Computing Overlay
                    if viewModel.isRunning && !viewModel.isAnimating {
                        ZStack {
                            Color.black.opacity(0.35)
                                .ignoresSafeArea()
                            VStack(spacing: 14) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(1.2)
                                    .tint(.white)
                                Text("Computing \(viewModel.currentAlgorithm?.rawValue ?? "")…")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                Text(viewModel.formattedElapsedTime)
                                    .font(.system(.title2, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                                    .animation(.linear(duration: 0.1), value: viewModel.elapsedTime)
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 22)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial.opacity(0.9))
                            )
                        }
                    }

                    // Generating Overlay
                    if viewModel.isGenerating {
                        GeneratingOverlay()
                    }
                }

                // Bottom Panel: Algorithms
                BottomControlSheet(viewModel: viewModel)
                    .shadow(radius: 2, y: -2)
            }
        }
        .sheet(item: $viewModel.metrics) { metrics in
            ResultsSheet(metrics: metrics)
        }
    }
}

// MARK: - Subviews



// MARK: - Node Legend
struct NodeLegend: View {
    private let items: [(Color, String)] = [
        (.green,  "Start"),
        (.red,    "Target"),
        (.yellow, "Path"),
        (.gray,   "Unexplored"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.1) { color, label in
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Empty Canvas
struct EmptyCanvasView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("No Graph Generated")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Choose a size below to generate a random graph")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Bottom Control Sheet
struct BottomControlSheet: View {
    @ObservedObject var viewModel: PathfindingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 16) {
                // ── Graph Generation ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Label("Generate Graph", systemImage: "square.grid.3x3.fill")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.5)

                    HStack(spacing: 8) {
                        ForEach(GraphSize.allCases, id: \.self) { size in
                            SizeButton(
                                title: size.rawValue,
                                isActive: viewModel.currentGraphSize == size,
                                isDisabled: viewModel.isGenerating || viewModel.isRunning
                            ) {
                                viewModel.generateGraph(size: size)
                            }
                        }
                    }
                }

                // ── Algorithm Selection ───────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Label("Run Algorithm", systemImage: "play.circle.fill")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.5)

                    // 2-column grid for better discoverability than horizontal scroll
                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(PathfindingAlgorithm.allCases) { algo in
                            let isCurrentAlgo = viewModel.currentAlgorithm == algo
                            let isCurrentRunning = isCurrentAlgo && viewModel.isRunning
                            AlgorithmButton(
                                title: isCurrentRunning ? "Stop" : algo.rawValue,
                                isActive: isCurrentAlgo,
                                isRunning: isCurrentRunning,
                                isDisabled: viewModel.graph == nil || (viewModel.isRunning && !isCurrentRunning) || viewModel.isGenerating
                            ) {
                                if isCurrentRunning {
                                    viewModel.stopAlgorithm()
                                } else {
                                    viewModel.runAlgorithm(algo)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Size Button
struct SizeButton: View {
    let title: String
    let isActive: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                )
                .foregroundStyle(isActive ? .white : .primary)
                .opacity(isDisabled ? 0.45 : 1.0)
        }
        .disabled(isDisabled)
    }
}

// MARK: - Algorithm Button
struct AlgorithmButton: View {
    let title: String
    let isActive: Bool
    let isRunning: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isRunning {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? (isRunning ? Color.red : Color.accentColor) : Color(UIColor.secondarySystemFill))
            )
            .foregroundStyle(isActive ? .white : .primary)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Generating Overlay
struct GeneratingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                    .tint(.white)
                Text("Generating Graph…")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.9))
            )
        }
    }
}

// MARK: - Results Sheet
struct ResultsSheet: View {
    let metrics: PathfindingMetrics

    @State private var showCoverageHelp = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MetricRow(icon: "circle.grid.3x3", label: "Total Nodes", value: "\(metrics.totalNodes) nodes", helpText: "Total nodes generated in this graph.")
                    MetricRow(icon: "point.topleft.down.curvedto.point.bottomright.up", label: "Path Length", value: "\(metrics.pathLength) nodes", helpText: "Nodes in the final path, including start and target.")
                    MetricRow(icon: "dollarsign", label: "Total Cost", value: String(format: "%.1f units", metrics.pathCost), helpText: "Physical length of the path. A* and Dijkstra minimize this.")
                } header: {
                    Text("Graph & Path")
                }

                Section {
                    MetricRow(icon: "timer", label: "Time Taken", value: metrics.timeFormatted, helpText: "Raw computation time to find the path.")
                    MetricRow(icon: "arrow.triangle.turn.up.right.diamond", label: "Steps Taken", value: "\(metrics.stepsTaken) steps", helpText: "Total movements made. Can be higher than Unique Explored if nodes are revisited.")
                    MetricRow(icon: "eye", label: "Unique Explored", value: "\(metrics.uniqueExploredCount) nodes", helpText: "Unique nodes visited. Lower means more efficient.")
                    MetricRow(icon: "memorychip", label: "Est. Memory", value: metrics.memoryUsedFormatted, helpText: "Estimated peak RAM used by the algorithm.")
                } header: {
                    Text("Algorithm Performance")
                }

                Section {
                    let efficiency = metrics.totalNodes > 0
                        ? Double(metrics.uniqueExploredCount) / Double(metrics.totalNodes) * 100
                        : 0
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Node Coverage")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button(action: { showCoverageHelp.toggle() }) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showCoverageHelp) {
                                Text("Percentage of nodes explored before finding the target. Lower is better.")
                                    .font(.subheadline)
                                    .padding()
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: 250)
                                    .presentationCompactAdaptation(.popover)
                            }
                            .help("Percentage of nodes explored before finding the target. Lower is better.")
                            Spacer()
                            Text(String(format: "%.1f%%", efficiency))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        ProgressView(value: efficiency / 100.0)
                            .progressViewStyle(.linear)
                            .tint(efficiency > 75 ? .orange : efficiency > 40 ? .yellow : .green)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Efficiency")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(metrics.algorithmName)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    var helpText: String? = nil

    @State private var showHelp = false

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.primary)
            if let helpText = helpText {
                Button(action: { showHelp.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHelp) {
                    Text(helpText)
                        .font(.subheadline)
                        .padding()
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 250)
                        .presentationCompactAdaptation(.popover)
                }
                .help(helpText)
            }
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Canvas View
struct GraphCanvasView: View {
    @ObservedObject var viewModel: PathfindingViewModel

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard let graph = viewModel.graph else { return }

                let box = viewModel.boundingBox
                guard box.width > 0 && box.height > 0 else { return }

                let padding: CGFloat = 20
                let drawW = size.width  - padding * 2
                let drawH = size.height - padding * 2

                let scaleX = drawW / box.width
                let scaleY = drawH / box.height
                let scale  = min(scaleX, scaleY)

                let tx = padding + (drawW - box.width  * scale) / 2 - box.minX * scale
                let ty = padding + (drawH - box.height * scale) / 2 - box.minY * scale

                context.translateBy(x: tx, y: ty)
                context.scaleBy(x: scale, y: scale)

                // ── Edges ────────────────────────────────────────────────────
                var edgePath   = Path()
                var drawnEdges = Set<String>()

                for edge in graph.edges {
                    let k1 = "\(edge.source)-\(edge.target)"
                    let k2 = "\(edge.target)-\(edge.source)"
                    guard !drawnEdges.contains(k1), !drawnEdges.contains(k2) else { continue }
                    drawnEdges.insert(k1)
                    if let n1 = graph.nodes[edge.source], let n2 = graph.nodes[edge.target] {
                        edgePath.move(to: n1.position)
                        edgePath.addLine(to: n2.position)
                    }
                }
                context.stroke(edgePath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.8 / scale)

                // ── Nodes ────────────────────────────────────────────────────
                let r: Double = 4.0 / scale

                for (_, node) in graph.nodes {
                    let status = viewModel.nodeStatuses[node.id] ?? .unvisited
                    let rect = CGRect(x: node.position.x - r, y: node.position.y - r,
                                      width: r * 2, height: r * 2)

                    if status == .unvisited {
                        context.fill(Path(ellipseIn: rect), with: .color(Color.gray.opacity(0.25)))
                    } else {
                        context.fill(Path(ellipseIn: rect), with: .color(colorForStatus(status)))
                    }
                }

                // ── Path edges (highlight) ───────────────────────────────────
                if viewModel.finalPath.count > 1 {
                    var pathTrace = Path()
                    if let firstNode = graph.nodes[viewModel.finalPath[0]] {
                        pathTrace.move(to: firstNode.position)
                        for i in 1..<viewModel.finalPath.count {
                            if let n = graph.nodes[viewModel.finalPath[i]] {
                                pathTrace.addLine(to: n.position)
                            }
                        }
                    }
                    context.stroke(pathTrace, with: .color(.yellow), lineWidth: 3.0 / scale)
                }

                // ── Start / Target drawn on top, larger ──────────────────────
                if let startId = viewModel.startNode, let startNode = graph.nodes[startId] {
                    let rS = r * 2.5
                    let rect = CGRect(x: startNode.position.x - rS, y: startNode.position.y - rS,
                                      width: rS * 2, height: rS * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.green))
                }
                if let targetId = viewModel.targetNode, let targetNode = graph.nodes[targetId] {
                    let rT = r * 2.5
                    let rect = CGRect(x: targetNode.position.x - rT, y: targetNode.position.y - rT,
                                      width: rT * 2, height: rT * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.red))
                }
            }
            .background(Color(UIColor.systemBackground))
            .overlay(
                VStack {
                    HStack {
                        NodeLegend()
                            .padding(.leading, 12)
                            .padding(.top, 12)
                        Spacer()
                    }
                    Spacer()
                }
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
