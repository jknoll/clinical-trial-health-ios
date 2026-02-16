import SwiftUI
import AVKit

struct SplashView: View {
    var onFinished: () -> Void

    @State private var player: AVPlayer?
    @State private var hasCompletedOnce = false

    var body: some View {
        VStack(spacing: 0) {
            // Video at top (~35% of screen)
            if let player {
                ZStack(alignment: .bottom) {
                    VideoPlayerView(player: player)
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height * 0.35)
                        .clipped()

                    // Gradient fade from video bg to page bg
                    LinearGradient(
                        colors: [Color(white: 0.99).opacity(0), Color(white: 0.98)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
                .background(Color(white: 0.99))
            }

            VStack(alignment: .leading, spacing: 16) {
                // App title
                Text("Clinical Trial Compass")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)

                // Description
                (Text("Clinical Trial Compass helps you find relevant clinical trials through a guided conversation based on ")
                    + Text("your health history and goals").bold()
                    + Text("."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)

                // Feature bullets
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("Select specific health data to import")
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.blue)
                    }

                    Label {
                        Text("Get matching trials right on your iPhone")
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Apple Health badge — centered at bottom
                Image("AppleHealthBadge")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            VStack(spacing: 0) {
                Color(white: 0.99) // matches video background
                Color(white: 0.98) // page background
            }
            .ignoresSafeArea()
        )
        .onAppear {
            guard let url = Bundle.main.url(forResource: "logo", withExtension: "mp4") else {
                onFinished()
                return
            }
            let item = AVPlayerItem(url: url)
            let avPlayer = AVPlayer(playerItem: item)
            self.player = avPlayer

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                avPlayer.seek(to: .zero)
                avPlayer.play()
                if !hasCompletedOnce {
                    hasCompletedOnce = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onFinished()
                    }
                }
            }

            avPlayer.play()
        }
    }
}

// MARK: - AVPlayer UIViewRepresentable (chromeless)

private struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(player: player)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()

    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
