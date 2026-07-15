//
//  ZoomableScrollView.swift
//  AIProjectino
//
//  Created by Crescenzo Di Franco on 22/03/2026.
//

import SwiftUI

// Magia Nera copiata da RealGO NON TOCCARE
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    private var minimumZoomScale: CGFloat
    private var maximumZoomScale: CGFloat
    var onViewReady: ((CGFloat) -> Void)?
    var onScaleChange: ((CGFloat) -> Void)?

    init(
        minimumZoomScale: CGFloat = 1.0,
        maximumZoomScale: CGFloat = 5.0,
        onViewReady: ((CGFloat) -> Void)? = nil,
        onScaleChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.minimumZoomScale = minimumZoomScale
        self.maximumZoomScale = maximumZoomScale
        self.onViewReady = onViewReady
        self.onScaleChange = onScaleChange
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.zoomScale = max(minimumZoomScale, 1.0)
        scrollView.bouncesZoom = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let hosting = context.coordinator.hostingController
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear
        scrollView.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hosting.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        DispatchQueue.main.async {
            self.onViewReady?(self.minimumZoomScale)
        }
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
        context.coordinator.onScaleChange = onScaleChange
        uiView.minimumZoomScale = minimumZoomScale
        uiView.maximumZoomScale = maximumZoomScale
        DispatchQueue.main.async {
            context.coordinator.scrollViewDidZoom(uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content, onScaleChange: onScaleChange)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>
        var onScaleChange: ((CGFloat) -> Void)?

        init(content: Content, onScaleChange: ((CGFloat) -> Void)?) {
            self.hostingController = UIHostingController(rootView: content)
            self.onScaleChange = onScaleChange
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let offsetX = max((scrollView.bounds.width  - scrollView.contentSize.width)  * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)

            DispatchQueue.main.async {
                self.onScaleChange?(scrollView.zoomScale)
            }
        }
    }
}
