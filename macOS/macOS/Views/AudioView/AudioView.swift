import SwiftUI

// MARK: - 音波动画视图
struct AudioWaveView: View {
    @State private var isAnimating = false
    
    // 可自定义的参数
    let barCount: Int
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let animationSpeed: Double
    let colors: [Color]
    
    init(
        barCount: Int = 5,
        barWidth: CGFloat = 4,
        barSpacing: CGFloat = 2,
        minHeight: CGFloat = 10,
        maxHeight: CGFloat = 50,
        animationSpeed: Double = 0.3,
        colors: [Color] = [.blue, .purple]
    ) {
        self.barCount = barCount
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.animationSpeed = animationSpeed
        self.colors = colors
    }
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                AudioBar(
                    minHeight: minHeight,
                    maxHeight: maxHeight,
                    animationSpeed: animationSpeed,
                    animationDelay: Double(index) * 0.1,
                    colors: colors,
                    isAnimating: isAnimating
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// MARK: - 单个音波条
struct AudioBar: View {
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let animationSpeed: Double
    let animationDelay: Double
    let colors: [Color]
    let isAnimating: Bool
    
    @State private var height: CGFloat
    
    init(minHeight: CGFloat, maxHeight: CGFloat, animationSpeed: Double, animationDelay: Double, colors: [Color], isAnimating: Bool) {
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.animationSpeed = animationSpeed
        self.animationDelay = animationDelay
        self.colors = colors
        self.isAnimating = isAnimating
        self._height = State(initialValue: minHeight)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 4, height: height)
            .animation(
                isAnimating ?
                Animation.easeInOut(duration: animationSpeed)
                    .repeatForever(autoreverses: true)
                    .delay(animationDelay) : .default,
                value: height
            )
            .onAppear {
                if isAnimating {
                    height = CGFloat.random(in: minHeight...maxHeight)
                }
            }
            .onChange(of: isAnimating) { newValue in
                if newValue {
                    height = CGFloat.random(in: minHeight...maxHeight)
                } else {
                    height = minHeight
                }
            }
    }
}

// MARK: - 圆形音波动画
struct CircularAudioWaveView: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    let color: Color
    let size: CGFloat
    let animationDuration: Double
    
    init(
        color: Color = .blue,
        size: CGFloat = 100,
        animationDuration: Double = 1.5
    ) {
        self.color = color
        self.size = size
        self.animationDuration = animationDuration
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(scale + CGFloat(index) * 0.2)
                    .opacity(opacity - Double(index) * 0.3)
                    .animation(
                        Animation.easeInOut(duration: animationDuration)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: scale
                    )
            }
        }
        .onAppear {
            scale = 1.3
            opacity = 0.3
        }
    }
}

// MARK: - 流畅的音波线条动画
struct SmoothWaveView: View {
    @State private var phase: CGFloat = 0
    
    let waveColor: Color
    let amplitude: CGFloat
    let frequency: CGFloat
    let animationDuration: Double
    
    init(
        waveColor: Color = .blue,
        amplitude: CGFloat = 20,
        frequency: CGFloat = 1.5,
        animationDuration: Double = 2.0
    ) {
        self.waveColor = waveColor
        self.amplitude = amplitude
        self.frequency = frequency
        self.animationDuration = animationDuration
    }
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, to: width, by: 1) {
                    let relativeX = x / width
                    let sine = sin(relativeX * .pi * frequency + phase)
                    let y = midHeight + sine * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(waveColor, lineWidth: 2)
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: animationDuration)
                    .repeatForever(autoreverses: false)
            ) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - 音乐播放状态指示器
struct MusicPlayingIndicator: View {
    @State private var isPlaying = false
    
    let barCount: Int
    let barWidth: CGFloat
    let color: Color
    
    init(
        barCount: Int = 3,
        barWidth: CGFloat = 3,
        color: Color = .green
    ) {
        self.barCount = barCount
        self.barWidth = barWidth
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(color)
                    .frame(width: barWidth, height: 15)
                    .scaleEffect(y: isPlaying ? CGFloat.random(in: 0.3...1.0) : 0.3)
                    .animation(
                        isPlaying ?
                        Animation.easeInOut(duration: Double.random(in: 0.3...0.5))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1) : .default,
                        value: isPlaying
                    )
            }
        }
        .frame(height: 16)
        .onAppear {
            isPlaying = true
        }
    }
}

// MARK: - Loading Dots Indicator
struct LoadingDotsIndicator: View {
    @State private var isAnimating = false
    
    let dotCount: Int
    let dotSize: CGFloat
    let spacing: CGFloat
    let color: Color
    let animationDuration: Double
    
    init(
        dotCount: Int = 3,
        dotSize: CGFloat = 4,
        spacing: CGFloat = 4,
        color: Color = .gray,
        animationDuration: Double = 0.6
    ) {
        self.dotCount = dotCount
        self.dotSize = dotSize
        self.spacing = spacing
        self.color = color
        self.animationDuration = animationDuration
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: animationDuration)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * (animationDuration / Double(dotCount))),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 16) // 保持与 MusicPlayingIndicator 相同高度
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - 示例视图
struct AudioExampleView: View {
    @State private var selectedStyle = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Text("音波动画示例")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Picker("动画样式", selection: $selectedStyle) {
                Text("条形音波").tag(0)
                Text("圆形脉冲").tag(1)
                Text("流畅波形").tag(2)
                Text("播放指示器").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            Spacer()
            
            // 根据选择显示不同的动画
            Group {
                switch selectedStyle {
                case 0:
                    VStack(spacing: 30) {
                        // 默认样式
                        AudioWaveView()
                        
                        // 自定义样式
                        AudioWaveView(
                            barCount: 7,
                            barWidth: 6,
                            barSpacing: 3,
                            minHeight: 15,
                            maxHeight: 80,
                            animationSpeed: 0.4,
                            colors: [.orange, .red]
                        )
                        
                        // 更多条数的样式
                        AudioWaveView(
                            barCount: 20,
                            barWidth: 3,
                            barSpacing: 1,
                            minHeight: 5,
                            maxHeight: 40,
                            animationSpeed: 0.25,
                            colors: [.green, .blue]
                        )
                    }
                    
                case 1:
                    VStack(spacing: 30) {
                        CircularAudioWaveView()
                        
                        HStack(spacing: 30) {
                            CircularAudioWaveView(
                                color: .purple,
                                size: 60,
                                animationDuration: 1.0
                            )
                            CircularAudioWaveView(
                                color: .orange,
                                size: 80,
                                animationDuration: 2.0
                            )
                        }
                    }
                    
                case 2:
                    VStack(spacing: 30) {
                        SmoothWaveView()
                            .frame(height: 100)
                        
                        SmoothWaveView(
                            waveColor: .purple,
                            amplitude: 30,
                            frequency: 2.0,
                            animationDuration: 1.5
                        )
                        .frame(height: 100)
                    }
                    
                case 3:
                    HStack(spacing: 40) {
                        MusicPlayingIndicator(
                            barCount: 6,
                        )
                        
                        MusicPlayingIndicator(
                            barCount: 5,
                            barWidth: 4,
                            color: .purple
                        )
                        
                        MusicPlayingIndicator(
                            barCount: 4,
                            barWidth: 2,
                            color: .orange
                        )
                    }
                    
                default:
                    EmptyView()
                }
            }
            .frame(height: 150)
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 600)
    }
}


#Preview {
    AudioExampleView()
}
