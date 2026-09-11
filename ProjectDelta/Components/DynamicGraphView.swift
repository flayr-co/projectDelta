//
//  DynamicGraphView.swift
//  ProjectDelta
//

import Foundation
import SwiftUI
import Charts

// MARK: - GraphData Model
public struct GraphData: Codable, Equatable {
    public struct Series: Codable, Equatable {
        public var label: String
        public var xValues: [Double]
        public var yValues: [Double]
        
        public init(label: String, xValues: [Double], yValues: [Double]) {
            self.label = label
            self.xValues = xValues
            self.yValues = yValues
        }
    }
    
    public var xValues: [Double]
    public var yValues: [Double]
    public var secondaryYValues: [Double]?
    public var inequality: Inequality?
    public var series: [Series]?
    
    public struct Inequality: Codable, Equatable {
        public var slope: Double
        public var intercept: Double
        public var shadeAbove: Bool
        
        public init(slope: Double, intercept: Double, shadeAbove: Bool) {
            self.slope = slope
            self.intercept = intercept
            self.shadeAbove = shadeAbove
        }
    }
    
    public init(xValues: [Double], yValues: [Double], secondaryYValues: [Double]? = nil, inequality: Inequality? = nil, series: [Series]? = nil) {
        self.xValues = xValues
        self.yValues = yValues
        self.secondaryYValues = secondaryYValues
        self.inequality = inequality
        self.series = series
    }
}

// Sample data for the graph
let sampleData = GraphData(
    xValues: [1.0, 2.0, 3.0, 4.0, 5.0],
    yValues: [5.0, 7.0, 9.0, 11.0, 13.0],
    secondaryYValues: [4.0, 3.0, 2.0, 1.0, 0.0]
)

struct DynamicGraphView: View {
    var data: GraphData
    var isFullScreenMode: Bool = false
    var isScrollLocked: Bool = false
    @State private var showFullScreen: Bool = false
    @Environment(\.colorScheme) var colorScheme

    // Uniform Cartesian Scaling State (1:1 Aspect Ratio)
    @State private var currentScale: CGFloat = 30.0
    @State private var lastScale: CGFloat = 30.0

    @State private var currentPan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    
    // Smart Bounding Box Tracking
    @State private var targetScale: CGFloat = 30.0
    @State private var targetPan: CGSize = .zero
    @State private var hasInitializedViewport: Bool = false

    // Interaction State
    @State private var probeLocation: CGPoint? = nil
    @State private var activeProbePoint: CGPoint? = nil
    @State private var isProbing: Bool = false
    @State private var intersectionPoints: [CGPoint] = []

    var primaryColor: Color { colorScheme == .dark ? Color(red: 0.15, green: 0.85, blue: 0.75) : .blue }
    private var seriesColors: [Color] {
        colorScheme == .dark
        ? [Color(red: 0.15, green: 0.85, blue: 0.75), Color(red: 1.0, green: 0.65, blue: 0.15), .pink, .cyan, .mint, .yellow]
        : [Color(red: 0.0, green: 0.4, blue: 0.8), Color(red: 0.5, green: 0.2, blue: 0.7), .teal, .orange, .pink, .indigo]
    }
    
    var primaryEquation: String {
        if let firstSeries = activeSeries.first {
            return firstSeries.label
        }
        return primaryEquationFromRegression
    }

    var secondaryEquation: String {
        if let secondaryYValues = data.secondaryYValues,
           let regressionLine = linearRegression(x: data.xValues, y: secondaryYValues) {
            let slope = String(format: (regressionLine.slope.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.slope)
            let intercept = String(format: (regressionLine.intercept.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.intercept)
            if abs(regressionLine.slope) < 0.0001 {
                return "y = \(intercept)"
            }
            return "y = \(slope)x \(regressionLine.intercept >= 0 ? "+" : "-") \(abs(Double(intercept) ?? 0).cleanGraphString)"
        } else {
            return "Secondary Line"
        }
    }

    private var activeSeries: [GraphData.Series] {
        if let series = data.series, !series.isEmpty {
            return series
        }
        
        var legacySeries = [GraphData.Series(label: primaryEquationFromRegression, xValues: data.xValues, yValues: data.yValues)]
        if let secondaryYValues = data.secondaryYValues {
            legacySeries.append(GraphData.Series(label: secondaryEquation, xValues: data.xValues, yValues: secondaryYValues))
        }
        return legacySeries
    }
    
    private var primaryEquationFromRegression: String {
        if let regressionLine = linearRegression(x: data.xValues, y: data.yValues) {
            let slope = String(format: (regressionLine.slope.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.slope)
            let intercept = String(format: (regressionLine.intercept.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.intercept)
            if abs(regressionLine.slope) < 0.0001 {
                return "y = \(intercept)"
            }
            return "y = \(slope)x \(regressionLine.intercept >= 0 ? "+" : "-") \(abs(Double(intercept) ?? 0).cleanGraphString)"
        }
        return "Primary Line"
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Integrated Minimalist Legend Ribbon
            if !activeSeries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(activeSeries.enumerated()), id: \.offset) { index, series in
                            let color = colorForSeries(at: index)
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: color.opacity(0.6), radius: 3, y: 0)
                                Text(series.label.formatAsMathPower)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? .white : color.opacity(0.9))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(color.opacity(colorScheme == .dark ? 0.15 : 0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(colorScheme == .dark ? Color(red: 0.10, green: 0.11, blue: 0.13) : Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.primary.opacity(0.06)),
                    alignment: .bottom
                )
                .zIndex(2)
            }
            
            // MARK: Core Render Canvas
            GeometryReader { geo in
                let size = geo.size
                let safeWidth = max(size.width, 100)
                let safeHeight = max(size.height, 100)
                let origin = CGPoint(x: safeWidth / 2 + currentPan.width, y: safeHeight / 2 + currentPan.height)
                
                let step = calculateGridStep(scale: currentScale)
                
                ZStack {
                    Canvas { context, canvasSize in
                        drawAdaptiveGrid(context: context, size: canvasSize, origin: origin, scale: currentScale, step: step)
                        
                        if let inequality = data.inequality {
                            drawInequality(context: context, inequality: inequality, origin: origin, scale: currentScale, canvasSize: canvasSize, color: primaryColor)
                        }
                        
                        // Draw Series Curves
                        for (index, series) in activeSeries.enumerated() {
                            let color = colorForSeries(at: index)
                            let cleanLabel = series.label.lowercased().replacingOccurrences(of: " ", with: "")
                            let isEquation = cleanLabel.hasPrefix("y=") || cleanLabel.contains("x") || Double(cleanLabel) != nil
                            
                            if isEquation, let evaluator = MathEngine.compile(series.label) {
                                drawEquationCurve(context: context, evaluator: evaluator, origin: origin, scale: currentScale, canvasSize: canvasSize, color: color)
                            } else {
                                drawDiscreteSeries(context: context, series: series, origin: origin, scale: currentScale, canvasSize: canvasSize, color: color)
                            }
                        }
                        
                        // Draw Intersections perfectly, passing the probe to prevent text clashing
                        drawIntersections(context: context, origin: origin, scale: currentScale, canvasSize: canvasSize, activeProbePoint: isProbing ? activeProbePoint : nil)
                    }
                    
                    // MARK: Invisible Interaction Layer
                    if !isScrollLocked {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                LongPressGesture(minimumDuration: 0.15, maximumDistance: 10)
                                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                                    .onChanged { value in
                                        switch value {
                                        case .second(true, let drag):
                                            if let location = drag?.location {
                                                if !isProbing {
                                                    isProbing = true
                                                    #if os(iOS)
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    #endif
                                                }
                                                probeLocation = location
                                            }
                                        default:
                                            break
                                        }
                                    }
                                    .onEnded { _ in
                                        isProbing = false
                                        probeLocation = nil
                                        activeProbePoint = nil
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 12)
                                    .onChanged { val in
                                        if !isProbing {
                                            currentPan = CGSize(
                                                width: lastPan.width + val.translation.width,
                                                height: lastPan.height + val.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        if !isProbing {
                                            lastPan = currentPan
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                MagnifyGesture()
                                    .onChanged { val in
                                        if !isProbing {
                                            let newScale = lastScale * val.magnification
                                            if newScale.isFinite && newScale > 0 {
                                                currentScale = max(2.0, min(newScale, 1000.0))
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        if !isProbing {
                                            lastScale = currentScale
                                        }
                                    }
                            )
                    }
                    
                    // MARK: Active Probe Overlay (Scrubbing)
                    if let probe = probeLocation, let closestData = findClosestPoint(to: probe, origin: origin, scale: currentScale) {
                        Path { p in
                            p.move(to: CGPoint(x: closestData.screenPoint.x, y: 0))
                            p.addLine(to: CGPoint(x: closestData.screenPoint.x, y: size.height))
                        }
                        .stroke(closestData.color.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        
                        Circle()
                            .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.15) : .white)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(closestData.color, lineWidth: 3.5))
                            .shadow(color: .black.opacity(0.3), radius: 6)
                            .position(closestData.screenPoint)
                        
                        Text("(\(closestData.mathX.cleanGraphString), \(closestData.mathY.cleanGraphString))")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? .white : closestData.color.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(closestData.color.opacity(colorScheme == .dark ? 0.35 : 0.12))
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                            .overlay(Capsule().stroke(closestData.color.opacity(0.5), lineWidth: 1))
                            .position(x: closestData.screenPoint.x, y: closestData.screenPoint.y - 45)
                            .onAppear { activeProbePoint = closestData.screenPoint }
                            .onChange(of: closestData.screenPoint) { _, newPt in activeProbePoint = newPt }
                    }
                    
                    // MARK: Viewport Controls
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Spacer()
                            
                            let isPanned = abs(currentPan.width - targetPan.width) > 2 || abs(currentPan.height - targetPan.height) > 2
                            let isZoomed = abs(currentScale - targetScale) > 1
                            
                            if isPanned || isZoomed {
                                Button(action: {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                        currentScale = targetScale
                                        lastScale = targetScale
                                        currentPan = targetPan
                                        lastPan = targetPan
                                    }
                                }) {
                                    Image(systemName: "scope")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                                        .padding(14)
                                        .background(Color.primary.opacity(0.08))
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                                }
                            }
                            
                            if !isFullScreenMode {
                                Button(action: {
                                    showFullScreen = true
                                }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(primaryColor)
                                        .padding(14)
                                        .background(Color.primary.opacity(0.08))
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
                .background(colorScheme == .dark ? Color(red: 0.08, green: 0.09, blue: 0.11) : Color(white: 0.98))
                .onAppear {
                    if !hasInitializedViewport {
                        applySmartScale(size: size)
                        hasInitializedViewport = true
                    }
                }
                .onChange(of: data) { _, _ in
                    applySmartScale(size: size)
                }
                .onChange(of: size) { _, newSize in
                    applySmartScale(size: newSize)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1.5))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, y: 8)
        .frame(maxWidth: .infinity)
        // Fluid boundaries allow perfect geometry adaptation on Mac and iOS
        .frame(minHeight: isFullScreenMode ? 300 : 350, maxHeight: isFullScreenMode ? .infinity : 600)
        .padding(.horizontal, isFullScreenMode ? 0 : nil)
        .padding(.vertical, isFullScreenMode ? 0 : 8)
#if os(iOS)
        .fullScreenCover(isPresented: $showFullScreen) {
            NavigationStack {
                ZStack {
                    Color.platformSystemGroupedBackground.ignoresSafeArea()
                    DynamicGraphView(data: data, isFullScreenMode: true)
                        .padding()
                }
                .navigationTitle("Graph Analysis")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showFullScreen = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
#elseif os(macOS)
        .sheet(isPresented: $showFullScreen) {
            NavigationStack {
                ZStack {
                    Color.platformSystemGroupedBackground.ignoresSafeArea()
                    DynamicGraphView(data: data, isFullScreenMode: true)
                        .padding()
                }
                .navigationTitle("Graph Analysis")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showFullScreen = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .frame(minWidth: 800, minHeight: 600)
            }
        }
#endif
    }
    
    // MARK: - Algorithmic 1:1 Camera System
    private func applySmartScale(size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        
        Task.detached(priority: .userInitiated) {
            var corePOIs: [CGPoint] = []
            
            func addPOI(_ pt: CGPoint) {
                if !corePOIs.contains(where: { hypot($0.x - pt.x, $0.y - pt.y) < 0.1 }) {
                    corePOIs.append(pt)
                }
            }
            
            let seriesList = activeSeries
            var intersections: [CGPoint] = []
            
            for i in 0..<seriesList.count {
                let s1 = seriesList[i]
                guard let e1 = MathEngine.compile(s1.label) else {
                    for j in 0..<s1.xValues.count { addPOI(CGPoint(x: s1.xValues[j], y: s1.yValues[j])) }
                    continue
                }
                
                // 1. Precise Intersection Tracking via Continuous Math Engine
                for k in (i+1)..<seriesList.count {
                    let s2 = seriesList[k]
                    guard let e2 = MathEngine.compile(s2.label) else { continue }
                    
                    let diff = { (x: Double) -> Double in e1(x) - e2(x) }
                    var pX = -50.0
                    var pDiff = diff(pX)
                    
                    for x in stride(from: -49.5, through: 50.0, by: 0.5) {
                        let cDiff = diff(x)
                        
                        // Standard Crossing
                        if pDiff * cDiff <= 0 {
                            var low = pX, high = x
                            for _ in 0..<20 {
                                let mid = (low + high) / 2
                                if (diff(mid) > 0) == (cDiff > 0) { high = mid } else { low = mid }
                            }
                            let rootX = (low + high) / 2
                            let rootY = e1(rootX)
                            if rootY.isFinite {
                                let pt = CGPoint(x: rootX, y: rootY)
                                addPOI(pt)
                                intersections.append(pt)
                            }
                        }
                        // Grazing Tangent (Local Minimum near zero)
                        else if abs(cDiff) < 0.5 {
                            let prevAbs = abs(diff(x - 0.1))
                            let nextAbs = abs(diff(x + 0.1))
                            if abs(cDiff) < prevAbs && abs(cDiff) < nextAbs {
                                var bestX = x
                                var minVal = abs(cDiff)
                                for fx in stride(from: x - 0.2, through: x + 0.2, by: 0.01) {
                                    let val = abs(diff(fx))
                                    if val < minVal { minVal = val; bestX = fx }
                                }
                                if minVal < 0.05 {
                                    let exactY = e1(bestX)
                                    if exactY.isFinite {
                                        let pt = CGPoint(x: bestX, y: exactY)
                                        addPOI(pt)
                                        intersections.append(pt)
                                    }
                                }
                            }
                        }
                        pX = x; pDiff = cDiff
                    }
                }
                
                // 2. Extrema (Vertices) and Intercepts
                let yInt = e1(0)
                if yInt.isFinite { addPOI(CGPoint(x: 0, y: yInt)) }
                
                var pX = -50.0
                var pY = e1(pX)
                var pSlope = (e1(-49.9) - pY) / 0.1
                
                for x in stride(from: -49.5, through: 50.0, by: 0.5) {
                    let cY = e1(x)
                    
                    // X intercept
                    if pY * cY <= 0 {
                        var low = pX, high = x
                        for _ in 0..<15 {
                            let mid = (low + high) / 2
                            if (e1(mid) > 0) == (cY > 0) { high = mid } else { low = mid }
                        }
                        addPOI(CGPoint(x: (low + high) / 2, y: 0))
                    }
                    
                    // Local vertex
                    let cSlope = (e1(x + 0.1) - cY) / 0.1
                    if pSlope * cSlope <= 0 && abs(cSlope) < 100 {
                        var bestX = x
                        var extY = cY
                        let isMin = pSlope < 0
                        for fx in stride(from: x - 0.5, through: x + 0.5, by: 0.05) {
                            let fy = e1(fx)
                            if isMin ? (fy < extY) : (fy > extY) { extY = fy; bestX = fx }
                        }
                        if extY.isFinite { addPOI(CGPoint(x: bestX, y: extY)) }
                    }
                    pX = x; pY = cY; pSlope = cSlope
                }
            }
            
            let validPOIs = corePOIs.filter { abs($0.x) <= 250 && abs($0.y) <= 250 }
            var minX = validPOIs.map(\.x).min() ?? -10.0
            var maxX = validPOIs.map(\.x).max() ?? 10.0
            var minY = validPOIs.map(\.y).min() ?? -10.0
            var maxY = validPOIs.map(\.y).max() ?? 10.0
            
            // Expand to Origin for context if nearby
            if maxX < 0 && maxX > -20 { maxX = 0 }
            if minX > 0 && minX < 20 { minX = 0 }
            if maxY < 0 && maxY > -20 { maxY = 0 }
            if minY > 0 && minY < 20 { minY = 0 }

            let minWindow: Double = 10.0
            if maxX - minX < minWindow {
                let cx = (maxX + minX) / 2
                minX = cx - (minWindow / 2)
                maxX = cx + (minWindow / 2)
            }
            if maxY - minY < minWindow {
                let cy = (maxY + minY) / 2
                minY = cy - (minWindow / 2)
                maxY = cy + (minWindow / 2)
            }
            
            // Apply 25% boundary padding
            let pX = (maxX - minX) * 0.25
            let pY = (maxY - minY) * 0.25
            minX -= pX; maxX += pX
            minY -= pY; maxY += pY
            
            // 1:1 Aspect Ratio Normalization: Symmetrically expand the tighter axis to fill the screen flawlessly
            let viewAspect = Double(size.width / size.height)
            let mathWidth = maxX - minX
            let mathHeight = maxY - minY
            let mathAspect = mathWidth / mathHeight
            
            if mathAspect < viewAspect {
                let neededWidth = mathHeight * viewAspect
                let diff = (neededWidth - mathWidth) / 2.0
                minX -= diff
                maxX += diff
            } else {
                let neededHeight = mathWidth / viewAspect
                let diff = (neededHeight - mathHeight) / 2.0
                minY -= diff
                maxY += diff
            }
            
            let finalScale = size.width / CGFloat(maxX - minX)
            let clampedScale = max(2.0, min(finalScale, 800.0))
            
            let centerX = (minX + maxX) / 2.0
            let centerY = (minY + maxY) / 2.0
            
            let newPan = CGSize(width: CGFloat(-centerX) * clampedScale, height: CGFloat(centerY) * clampedScale)
            
            await MainActor.run {
                self.intersectionPoints = intersections
                self.targetScale = clampedScale
                self.targetPan = newPan
                
                withAnimation(.spring(response: 0.65, dampingFraction: 0.8)) {
                    self.currentScale = clampedScale
                    self.lastScale = clampedScale
                    self.currentPan = newPan
                    self.lastPan = newPan
                }
            }
        }
    }

    private func colorForSeries(at index: Int) -> Color {
        seriesColors[index % seriesColors.count]
    }
    
    // MARK: - Mathematical Probe Calculator
    private func findClosestPoint(to location: CGPoint, origin: CGPoint, scale: CGFloat) -> (screenPoint: CGPoint, mathX: Double, mathY: Double, color: Color)? {
        let mathX = Double((location.x - origin.x) / scale)
        var closestMatch: (screenPoint: CGPoint, mathY: Double, color: Color)? = nil
        var minVerticalDistance: CGFloat = .infinity
        
        for (index, series) in activeSeries.enumerated() {
            let color = colorForSeries(at: index)
            let cleanLabel = series.label.lowercased().replacingOccurrences(of: " ", with: "")
            let isEquation = cleanLabel.hasPrefix("y=") || cleanLabel.contains("x") || Double(cleanLabel) != nil
            
            if isEquation, let evaluator = MathEngine.compile(series.label) {
                let mathY = evaluator(mathX)
                if !mathY.isNaN && !mathY.isInfinite {
                    let screenY = origin.y - CGFloat(mathY) * scale
                    let verticalDist = abs(screenY - location.y)
                    
                    if verticalDist < minVerticalDistance {
                        minVerticalDistance = verticalDist
                        closestMatch = (CGPoint(x: location.x, y: screenY), mathY, color)
                    }
                }
            } else if !series.xValues.isEmpty {
                if let closestIdx = series.xValues.indices.min(by: { abs(series.xValues[$0] - mathX) < abs(series.xValues[$1] - mathX) }) {
                    let cMathX = series.xValues[closestIdx]
                    let cMathY = series.yValues[closestIdx]
                    
                    let sx = origin.x + CGFloat(cMathX) * scale
                    let sy = origin.y - CGFloat(cMathY) * scale
                    let verticalDist = hypot(sx - location.x, sy - location.y)
                    
                    if verticalDist < minVerticalDistance {
                        minVerticalDistance = verticalDist
                        closestMatch = (CGPoint(x: sx, y: sy), cMathY, color)
                    }
                }
            }
        }
        
        if let match = closestMatch {
            return (screenPoint: match.screenPoint, mathX: mathX, mathY: match.mathY, color: match.color)
        }
        return nil
    }

    // MARK: - Adaptive Grid System
    private func calculateGridStep(scale: CGFloat) -> CGFloat {
        let targetSpacing: CGFloat = 80.0
        let rawStep = targetSpacing / scale
        let mag = pow(10.0, floor(log10(rawStep)))
        let normalized = rawStep / mag
        
        if normalized < 2.0 { return 1.0 * mag }
        if normalized < 5.0 { return 2.0 * mag }
        return 5.0 * mag
    }
    
    private func drawAdaptiveGrid(context: GraphicsContext, size: CGSize, origin: CGPoint, scale: CGFloat, step: CGFloat) {
        let minXMath = -origin.x / scale
        let maxXMath = (size.width - origin.x) / scale
        let minYMath = (origin.y - size.height) / scale
        let maxYMath = origin.y / scale
        
        var minorPath = Path()
        
        var x = floor(minXMath / step) * step
        while x <= maxXMath {
            let sx = origin.x + x * scale
            minorPath.move(to: CGPoint(x: sx, y: 0))
            minorPath.addLine(to: CGPoint(x: sx, y: size.height))
            
            if abs(x) > 0.0001 {
                let text = Text(x.cleanMathString).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.6))
                context.draw(text, at: CGPoint(x: sx + 4, y: origin.y + 6), anchor: .topLeading)
            }
            x += step
        }
        
        var y = floor(minYMath / step) * step
        while y <= maxYMath {
            let sy = origin.y - y * scale
            minorPath.move(to: CGPoint(x: 0, y: sy))
            minorPath.addLine(to: CGPoint(x: size.width, y: sy))
            
            if abs(y) > 0.0001 {
                let text = Text(y.cleanMathString).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.6))
                context.draw(text, at: CGPoint(x: origin.x - 6, y: sy - 4), anchor: .bottomTrailing)
            }
            y += step
        }
        
        context.stroke(minorPath, with: .color(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.05)), lineWidth: 1)
        
        var axesPath = Path()
        axesPath.move(to: CGPoint(x: origin.x, y: 0))
        axesPath.addLine(to: CGPoint(x: origin.x, y: size.height))
        axesPath.move(to: CGPoint(x: 0, y: origin.y))
        axesPath.addLine(to: CGPoint(x: size.width, y: origin.y))
        
        context.stroke(axesPath, with: .color(Color.primary.opacity(0.25)), lineWidth: 2)
        
        let zeroText = Text("0").font(.system(size: 11, weight: .black, design: .rounded)).foregroundColor(.secondary.opacity(0.8))
        context.draw(zeroText, at: CGPoint(x: origin.x - 6, y: origin.y + 6), anchor: .topTrailing)
    }
    
    private func drawEquationCurve(context: GraphicsContext, evaluator: @escaping (Double) -> Double, origin: CGPoint, scale: CGFloat, canvasSize: CGSize, color: Color) {
        var path = Path()
        var isFirst = true
        var previousScreenY: CGFloat? = nil
        
        for screenX in stride(from: 0, through: canvasSize.width, by: 1.5) {
            let mathX = Double((screenX - origin.x) / scale)
            let mathY = evaluator(mathX)
            
            if mathY.isNaN || mathY.isInfinite {
                isFirst = true
                previousScreenY = nil
                continue
            }
            
            let screenY = origin.y - CGFloat(mathY) * scale
            
            if let prevY = previousScreenY, abs(screenY - prevY) > canvasSize.height {
                isFirst = true
            }
            
            let pt = CGPoint(x: screenX, y: screenY)
            
            if screenY >= -1000 && screenY <= canvasSize.height + 1000 {
                if isFirst {
                    path.move(to: pt)
                    isFirst = false
                } else {
                    path.addLine(to: pt)
                }
                previousScreenY = screenY
            } else {
                isFirst = true
                previousScreenY = nil
            }
        }
        
        if colorScheme == .dark {
            context.stroke(path, with: .color(color.opacity(0.2)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
    }
    
    private func drawDiscreteSeries(context: GraphicsContext, series: GraphData.Series, origin: CGPoint, scale: CGFloat, canvasSize: CGSize, color: Color) {
        let validCount = min(series.xValues.count, series.yValues.count)
        guard validCount > 0 else { return }
        
        var path = Path()
        var isFirst = true
        
        let sortedIndices = (0..<validCount).sorted { series.xValues[$0] < series.xValues[$1] }
        
        for index in sortedIndices {
            let x = series.xValues[index]
            let y = series.yValues[index]
            
            if x.isNaN || y.isNaN || x.isInfinite || y.isInfinite {
                isFirst = true
                continue
            }
            
            let screenX = origin.x + CGFloat(x) * scale
            let screenY = origin.y - CGFloat(y) * scale
            let pt = CGPoint(x: screenX, y: screenY)
            
            if isFirst {
                path.move(to: pt)
                isFirst = false
            } else {
                path.addLine(to: pt)
            }
            
            if validCount <= 24 {
                let rect = CGRect(x: screenX - 5, y: screenY - 5, width: 10, height: 10)
                let pointPath = Path(ellipseIn: rect)
                context.fill(pointPath, with: .color(colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.15) : .white))
                context.stroke(pointPath, with: .color(color), lineWidth: 3)
            }
        }
        
        if colorScheme == .dark {
            context.stroke(path, with: .color(color.opacity(0.25)), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Algorithmic Label Repulsion
    private func drawIntersections(context: GraphicsContext, origin: CGPoint, scale: CGFloat, canvasSize: CGSize, activeProbePoint: CGPoint?) {
        var drawnRects: [CGRect] = []
        
        for pt in intersectionPoints {
            let screenX = origin.x + CGFloat(pt.x) * scale
            let screenY = origin.y - CGFloat(pt.y) * scale
            
            if screenX >= -50 && screenX <= canvasSize.width + 50 && screenY >= -50 && screenY <= canvasSize.height + 50 {
                
                // Hide the static intersection label entirely if the user is scrubbing directly over it
                if let probe = activeProbePoint, hypot(probe.x - screenX, probe.y - screenY) < 15 {
                    continue
                }
                
                // Precision Inner Dot
                let dotRect = CGRect(x: screenX - 3.5, y: screenY - 3.5, width: 7, height: 7)
                let dotPath = Path(ellipseIn: dotRect)
                context.fill(dotPath, with: .color(colorScheme == .dark ? .white : Color(white: 0.15)))
                
                // Outer Safety Ring
                let ringRect = CGRect(x: screenX - 8, y: screenY - 8, width: 16, height: 16)
                let ringPath = Path(ellipseIn: ringRect)
                context.stroke(ringPath, with: .color(colorScheme == .dark ? .white : Color(white: 0.15)), lineWidth: 2.5)
                
                let labelStr = "(\(Double(pt.x).cleanGraphString), \(Double(pt.y).cleanGraphString))"
                let font = Font.system(size: 13, weight: .bold, design: .monospaced)
                
                // Resolve text to calculate exact framing
                let resolvedText = context.resolve(Text(labelStr).font(font).foregroundColor(.primary))
                let textSize = resolvedText.measure(in: CGSize(width: 200, height: 50))
                
                let paddingX: CGFloat = 10
                let paddingY: CGFloat = 6
                let boxWidth = textSize.width + paddingX * 2
                let boxHeight = textSize.height + paddingY * 2
                
                // Default placement on the right
                var boxX = screenX + 16
                var boxY = screenY - boxHeight / 2
                
                // Flip to left if it bleeds off the right edge of the canvas
                var flipped = false
                if boxX + boxWidth > canvasSize.width - 10 {
                    boxX = screenX - 16 - boxWidth
                    flipped = true
                }
                
                var pillRect = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)
                
                // Active Collision Resolution: Push down if colliding with existing label
                while drawnRects.contains(where: { $0.intersects(pillRect.insetBy(dx: -4, dy: -4)) }) {
                    boxY += (boxHeight + 4)
                    pillRect = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)
                }
                drawnRects.append(pillRect)
                
                // Draw Bezier Connector to moving label
                var connector = Path()
                connector.move(to: CGPoint(x: flipped ? screenX - 8 : screenX + 8, y: screenY))
                let ctrlX = flipped ? screenX - 12 : screenX + 12
                connector.addQuadCurve(to: CGPoint(x: flipped ? boxX + boxWidth : boxX, y: pillRect.midY), control: CGPoint(x: ctrlX, y: pillRect.midY))
                context.stroke(connector, with: .color(Color.primary.opacity(0.3)), lineWidth: 1.5)
                
                // Draw Geometric Pill Background
                let pillPath = Path(roundedRect: pillRect, cornerRadius: 8)
                context.fill(pillPath, with: .color(colorScheme == .dark ? Color(white: 0.12) : Color.white))
                context.stroke(pillPath, with: .color(Color.primary.opacity(0.15)), lineWidth: 1)
                
                // Draw Text perfectly centered in the pill
                context.draw(resolvedText, at: CGPoint(x: pillRect.midX, y: pillRect.midY), anchor: .center)
            }
        }
    }
    
    private func drawInequality(context: GraphicsContext, inequality: GraphData.Inequality, origin: CGPoint, scale: CGFloat, canvasSize: CGSize, color: Color) {
        var path = Path()
        let m = CGFloat(inequality.slope)
        let b = CGFloat(inequality.intercept)
        
        let mathX1 = (0 - origin.x) / scale
        let mathX2 = (canvasSize.width - origin.x) / scale
        
        let mathY1 = m * mathX1 + b
        let mathY2 = m * mathX2 + b
        
        let screenY1 = origin.y - mathY1 * scale
        let screenY2 = origin.y - mathY2 * scale
        
        path.move(to: CGPoint(x: 0, y: screenY1))
        path.addLine(to: CGPoint(x: canvasSize.width, y: screenY2))
        
        if inequality.shadeAbove {
            path.addLine(to: CGPoint(x: canvasSize.width, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
        } else {
            path.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
            path.addLine(to: CGPoint(x: 0, y: canvasSize.height))
        }
        path.closeSubpath()
        
        context.fill(path, with: .color(color.opacity(colorScheme == .dark ? 0.24 : 0.14)))
    }
}

// MARK: - Advanced High-Performance Swift Math Engine
public enum MathEngine {
    
    enum Token: Equatable {
        case number(Double)
        case variable
        case op(Operator)
        case function(MathFunction)
        case openParen
        case closeParen
    }
    
    enum Operator: Character {
        case add = "+", sub = "-", mul = "*", div = "/", pow = "^"
        var precedence: Int {
            switch self { case .add, .sub: return 1; case .mul, .div: return 2; case .pow: return 3 }
        }
        var isRightAssociative: Bool { self == .pow }
    }
    
    enum MathFunction: String {
        case sin, cos, tan, ln, log, sqrt, abs
    }
    
    public static func compile(_ equation: String) -> ((Double) -> Double)? {
        let tokens = tokenize(equation)
        guard !tokens.isEmpty else { return nil }
        let rpn = toRPN(tokens)
        
        return { x in
            evaluateRPN(rpn, x: x)
        }
    }
    
    public static func samplePoints(for equation: String, domain: ClosedRange<Double> = -100...100, step: Double = 0.5) -> GraphData.Series? {
        guard let evaluator = compile(equation) else { return nil }
        
        var xVals: [Double] = []
        var yVals: [Double] = []
        var previousY: Double? = nil
        
        for x in stride(from: domain.lowerBound, through: domain.upperBound, by: step) {
            let y = evaluator(x)
            
            if y.isNaN || y.isInfinite || abs(y) > 5000 {
                xVals.append(x)
                yVals.append(.nan)
                previousY = nil
            } else {
                if let prev = previousY, abs(y - prev) > 100 {
                    xVals.append(x - step/2)
                    yVals.append(.nan)
                }
                xVals.append(x)
                yVals.append(y)
                previousY = y
            }
        }
        
        guard !xVals.isEmpty else { return nil }
        let label = equation.lowercased().hasPrefix("y=") ? equation : "y = \(equation)"
        return GraphData.Series(label: label, xValues: xVals, yValues: yVals)
    }
    
    private static func tokenize(_ eq: String) -> [Token] {
        var tokens: [Token] = []
        let cleanEq = eq.lowercased().replacingOccurrences(of: "y=", with: "").replacingOccurrences(of: " ", with: "")
        let chars = Array(cleanEq)
        var index = 0
        
        while index < chars.count {
            let char = chars[index]
            
            if char.isNumber || char == "." {
                var numStr = ""
                while index < chars.count && (chars[index].isNumber || chars[index] == ".") {
                    numStr.append(chars[index])
                    index += 1
                }
                if let val = Double(numStr) {
                    tokens.append(.number(val))
                    if index < chars.count && (chars[index] == "x" || chars[index] == "(" || chars[index].isLetter) {
                        tokens.append(.op(.mul))
                    }
                }
                continue
            }
            
            if char == "x" {
                tokens.append(.variable)
                index += 1
                if index < chars.count && (chars[index] == "(" || chars[index].isNumber || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            
            if char == "e" {
                tokens.append(.number(M_E))
                index += 1
                if index < chars.count && (chars[index] == "(" || chars[index].isNumber || chars[index] == "x" || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            
            if char == "p" && index + 1 < chars.count && chars[index+1] == "i" {
                tokens.append(.number(.pi))
                index += 2
                if index < chars.count && (chars[index] == "(" || chars[index].isNumber || chars[index] == "x" || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            
            if char.isLetter {
                var fnStr = ""
                while index < chars.count && chars[index].isLetter {
                    fnStr.append(chars[index])
                    index += 1
                }
                if let fn = MathFunction(rawValue: fnStr) {
                    tokens.append(.function(fn))
                }
                continue
            }
            
            if let op = Operator(rawValue: char) {
                if op == .sub {
                    let isUnary = tokens.isEmpty ||
                    (tokens.last != .variable && tokens.last != .closeParen &&
                     (tokens.last == .openParen || isOperator(tokens.last)))
                    
                    if isUnary {
                        tokens.append(.number(-1))
                        tokens.append(.op(.mul))
                        index += 1
                        continue
                    }
                }
                tokens.append(.op(op))
                index += 1
                continue
            }
            
            if char == "(" {
                tokens.append(.openParen)
                index += 1
                continue
            }
            if char == ")" {
                tokens.append(.closeParen)
                index += 1
                if index < chars.count && (chars[index] == "x" || chars[index].isNumber || chars[index] == "(" || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            index += 1
        }
        return tokens
    }
    
    private static func isOperator(_ token: Token?) -> Bool {
        guard let token = token else { return false }
        if case .op = token { return true }
        return false
    }
    
    private static func toRPN(_ tokens: [Token]) -> [Token] {
        var output: [Token] = []
        var opStack: [Token] = []
        
        for token in tokens {
            switch token {
            case .number, .variable:
                output.append(token)
            case .function:
                opStack.append(token)
            case .op(let o1):
                while let last = opStack.last {
                    if case .function = last {
                        output.append(opStack.removeLast())
                        continue
                    }
                    if case .op(let o2) = last {
                        if (!o1.isRightAssociative && o1.precedence <= o2.precedence) ||
                           (o1.isRightAssociative && o1.precedence < o2.precedence) {
                            output.append(opStack.removeLast())
                            continue
                        }
                    }
                    break
                }
                opStack.append(token)
            case .openParen:
                opStack.append(token)
            case .closeParen:
                while let last = opStack.last, last != .openParen {
                    output.append(opStack.removeLast())
                }
                if opStack.last == .openParen {
                    opStack.removeLast()
                }
                if let last = opStack.last, case .function = last {
                    output.append(opStack.removeLast())
                }
            }
        }
        while let last = opStack.last {
            output.append(opStack.removeLast())
        }
        return output
    }
    
    private static func evaluateRPN(_ rpn: [Token], x: Double) -> Double {
        var stack: [Double] = []
        for token in rpn {
            switch token {
            case .number(let val):
                stack.append(val)
            case .variable:
                stack.append(x)
            case .op(let op):
                let b = stack.popLast() ?? 0
                let a = stack.popLast() ?? 0
                switch op {
                case .add: stack.append(a + b)
                case .sub: stack.append(a - b)
                case .mul: stack.append(a * b)
                case .div: stack.append(a / b)
                case .pow: stack.append(pow(a, b))
                }
            case .function(let fn):
                let a = stack.popLast() ?? 0
                switch fn {
                case .sin: stack.append(sin(a))
                case .cos: stack.append(cos(a))
                case .tan: stack.append(tan(a))
                case .ln: stack.append(log(a))
                case .log: stack.append(log10(a))
                case .sqrt: stack.append(a < 0 ? .nan : sqrt(a))
                case .abs: stack.append(abs(a))
                }
            default: break
            }
        }
        return stack.first ?? .nan
    }
}

enum GraphContentParser {
    static func graphData(from content: String, graphType: String? = nil) -> GraphData {
        let normalizedType = graphType?.lowercased() ?? ""
        let normalizedContent = graphContent(from: content)
        let isPointsGraph = normalizedType.contains("point") || normalizedContent.contains("(")

        if isPointsGraph, let pointsData = pointsGraphData(from: normalizedContent) {
            return pointsData
        }

        return equationGraphData(from: normalizedContent)
    }

    static func graphType(from legacyGraphString: String) -> String? {
        if legacyGraphString.contains("type=points") {
            return QuestionGraphType.points.rawValue
        }
        if legacyGraphString.contains("type=equation") {
            return QuestionGraphType.equation.rawValue
        }
        return nil
    }

    static func graphContent(from legacyGraphString: String) -> String {
        if let equationRange = legacyGraphString.range(of: "equation=") {
            return String(legacyGraphString[equationRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let pointsRange = legacyGraphString.range(of: "points=") {
            return String(legacyGraphString[pointsRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return legacyGraphString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func pointsGraphData(from content: String) -> GraphData? {
        let cleanedContent = content
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "type=points", with: "")
            .replacingOccurrences(of: "points=", with: "")
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: "\n", with: "")

        var xValues: [Double] = []
        var yValues: [Double] = []
        let pointStrings = cleanedContent.components(separatedBy: "),(")

        for pointString in pointStrings {
            let coordinates = pointString
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .components(separatedBy: ",")

            if coordinates.count == 2,
               let xValue = Double(coordinates[0]),
               let yValue = Double(coordinates[1]) {
                xValues.append(xValue)
                yValues.append(yValue)
            }
        }

        guard !xValues.isEmpty else { return nil }
        return GraphData(xValues: xValues, yValues: yValues)
    }

    private static func equationGraphData(from content: String) -> GraphData {
        let cleanedContent = graphContent(from: content)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "type=equation", with: "")
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: "\n", with: "|")
        
        let components = cleanedContent.components(separatedBy: "|")
        if components.count > 1 {
            var allSeries: [GraphData.Series] = []
            var primaryX: [Double] = [-10.0, 10.0]
            var primaryY: [Double] = [-10.0, 10.0]
            var secondaryY: [Double]? = nil
            
            for (index, component) in components.enumerated() {
                let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                
                let eqString = trimmed.replacingOccurrences(of: "y=", with: "")
                if let sampled = MathEngine.samplePoints(for: eqString) {
                    allSeries.append(sampled)
                    if index == 0 {
                        primaryX = sampled.xValues
                        primaryY = sampled.yValues
                    } else if index == 1 {
                        secondaryY = sampled.yValues
                    }
                } else {
                    let line = lineValues(from: eqString)
                    let xValues = [-10.0, 10.0]
                    let yValues = xValues.map { line.slope * $0 + line.intercept }
                    let label = trimmed.hasPrefix("y=") ? trimmed : "y = \(trimmed)"
                    allSeries.append(GraphData.Series(label: label, xValues: xValues, yValues: yValues))
                    
                    if index == 0 {
                        primaryX = xValues
                        primaryY = yValues
                    } else if index == 1 {
                        secondaryY = yValues
                    }
                }
            }
            
            return GraphData(
                xValues: primaryX,
                yValues: primaryY,
                secondaryYValues: secondaryY,
                series: allSeries.isEmpty ? nil : allSeries
            )
        }
        
        let singleEq = cleanedContent.replacingOccurrences(of: "y=", with: "")
        if let sampled = MathEngine.samplePoints(for: singleEq) {
            return GraphData(xValues: sampled.xValues, yValues: sampled.yValues, series: [sampled])
        }
        
        if cleanedContent.starts(with: "x=") {
            let xValue = Double(cleanedContent.replacingOccurrences(of: "x=", with: "")) ?? 0.0
            return GraphData(xValues: [xValue, xValue], yValues: [-10.0, 10.0])
        }
        
        for inequalityOperator in [">=", "<=", ">", "<"] {
            let prefix = "y\(inequalityOperator)"
            if cleanedContent.starts(with: prefix) {
                let equation = String(cleanedContent.dropFirst(prefix.count))
                let line = lineValues(from: equation)
                let xValues = [-10.0, 10.0]
                let yValues = xValues.map { line.slope * $0 + line.intercept }
                return GraphData(
                    xValues: xValues,
                    yValues: yValues,
                    inequality: GraphData.Inequality(
                        slope: line.slope,
                        intercept: line.intercept,
                        shadeAbove: inequalityOperator.contains(">")
                    )
                )
            }
        }
        
        let equation = cleanedContent.replacingOccurrences(of: "y=", with: "")
        let line = lineValues(from: equation)
        
        let xValues = [-10.0, 10.0]
        let yValues = xValues.map { line.slope * $0 + line.intercept }
        return GraphData(xValues: xValues, yValues: yValues)
    }
    
    private static func lineValues(from equation: String) -> (slope: Double, intercept: Double) {
        let cleaned = equation.replacingOccurrences(of: " ", with: "")
        if cleaned.contains("x**") || cleaned.contains("x^") {
            return (slope: 0.0, intercept: 0.0)
        }
        
        let components = cleaned.components(separatedBy: "x")
        guard components.count == 2 else {
            let intercept = Double(cleaned) ?? 0.0
            return (slope: 0.0, intercept: intercept)
        }
        
        let slopeStr = components[0]
        let slope: Double
        if slopeStr.isEmpty || slopeStr == "+" {
            slope = 1.0
        } else if slopeStr == "-" {
            slope = -1.0
        } else {
            slope = Double(slopeStr) ?? 1.0
        }
        
        let interceptStr = components[1]
        let intercept = Double(interceptStr) ?? 0.0
        
        return (slope: slope, intercept: intercept)
    }
}

func linearRegression(x: [Double], y: [Double]) -> (slope: Double, intercept: Double)? {
    guard x.count == y.count && x.count > 1 else { return nil }
    
    let n = Double(x.count)
    let sumX = x.reduce(0, +)
    let sumY = y.reduce(0, +)
    let sumXY = zip(x, y).map(*).reduce(0, +)
    let sumXSquare = x.map { $0 * $0 }.reduce(0, +)
    
    let denominator = (n * sumXSquare - sumX * sumX)
    if denominator == 0 { return (0, 0) }
    
    let slope = (n * sumXY - sumX * sumY) / denominator
    let intercept = (sumY - slope * sumX) / n
    
    return (slope, intercept)
}

extension Double {
    var cleanGraphString: String {
        let val = abs(self) < 0.0001 ? 0.0 : self
        let rounded = (val * 100).rounded() / 100
        return rounded.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", rounded) : String(format: "%.2f", rounded)
    }
}

extension CGFloat {
    var cleanMathString: String {
        let val = abs(self) < 0.0001 ? 0.0 : self
        let rounded = (val * 100).rounded() / 100
        return rounded.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", rounded) : String(format: "%.2f", rounded)
    }
}

extension String {
    var formatAsMathPower: String {
        let superscripts: [Character: Character] = [
            "0":"⁰", "1":"¹", "2":"²", "3":"³", "4":"⁴",
            "5":"⁵", "6":"⁶", "7":"⁷", "8":"⁸", "9":"⁹",
            "-":"⁻", "+":"⁺", "x":"ˣ", "y":"ʸ", "n":"ⁿ"
        ]
        var result = ""
        var i = self.startIndex
        var isExponent = false
        var expectSign = false
        
        while i < self.endIndex {
            let char = self[i]
            if char == "^" {
                isExponent = true
                expectSign = true
                i = self.index(after: i)
                continue
            }
            
            if isExponent {
                if expectSign && (char == "-" || char == "+") {
                    result.append(superscripts[char]!)
                    expectSign = false
                } else if char.isNumber || char == "." || char.isLetter {
                    if let sup = superscripts[char] {
                        result.append(sup)
                    } else {
                        result.append(char)
                    }
                    expectSign = false
                } else {
                    isExponent = false
                    result.append(char)
                }
            } else {
                result.append(char)
            }
            i = self.index(after: i)
        }
        return result
    }
}
