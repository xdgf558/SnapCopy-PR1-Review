import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var userIdentityManager: UserIdentityManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var usageLimiter: UsageLimiter
    @EnvironmentObject private var appLanguageManager: AppLanguageManager

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var imageLoadError: String?
    @State private var captions: [CaptionCandidate] = []
    @State private var currentCaptionIndex = 0
    @State private var isGeneratingCaptions = false
    @State private var captionGenerationError: String?
    @State private var isCloudEnhancingCaptions = false
    @State private var cloudEnhancementPhase: CloudEnhancementPhase = .idle
    @State private var cloudEnhancementError: String?
    @State private var cloudEnhancementStatusMessage: String?
    @State private var cloudBackendRemainingQuota: Int?
    @State private var contributionStatusMessage: String?
    @State private var pendingTrainingContributionPrompt: TrainingContributionPrompt?
    @State private var copyConfirmationMessage: String?
    @State private var copyConfirmationID = UUID()
    @State private var selectedEnhancementPreset: ImageEnhancementPreset = .natural
    @State private var enhancedImage: UIImage?
    @State private var shareDraft: CaptionShareDraft?
    @State private var sharePayload: SharePayload?
    @State private var isPaywallPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var localAIStatusText = ""
    @State private var localAIStatusDetail = ""
    @State private var lastGenerationMode: CaptionGenerationMode?
    @State private var lastGenerationStatusMessage: String?
    @State private var imageAnalysisResult: ImageAnalysisResult?
    @State private var imageUnderstandingResult: ImageUnderstandingResult?
    @State private var isUnderstandingImage = false
    @State private var imageUnderstandingError: String?
    @State private var manualSceneSelection: ManualSceneOption = .auto
    @State private var selectedPlatform: SocialPlatform = .general
    @State private var selectedLengthLevel: LengthLevel = .medium
    @State private var imageUnderstandingRequestID = UUID()
    @State private var imageSelectionID = UUID()
    @State private var captionGenerationRequestID = UUID()
    @State private var favoriteCaptionKeys: Set<String> = []
    @State private var selectedCreativeImageStyle: CreativeImageStyle = .cuteHandDrawn
    @State private var creativeImage: UIImage?
    @State private var isGeneratingCreativeImage = false
    @State private var creativeImageError: String?
    @State private var creativeImageStatusMessage: String?
    @State private var isImageAnalysisDebugPresented = false
    @State private var isRecommendationDebugPresented = false
    @State private var lastFoundationPrompt = ""
    @State private var lastFoundationRawResult = ""
    @State private var lastRecommendationResult: CaptionRecommendationResult?
    @State private var recommendationFeedbackEvents: [RecommendationFeedbackEvent] = []
    @State private var currentCaptionShownAt = Date()

    private let captionService: CaptionService = CaptionGenerationService()
    private let cloudEnhancementService = CloudEnhancementService()
    private let trainingContributionService = TrainingContributionService()
    private let ratingStore = RatingStore()
    private let historyStore = CaptionHistoryStore()
    private let captionSampleStore = CaptionSampleLibraryStore()
    private let trainingContributionStore = TrainingContributionStore()
    private let shareCardTemplateStore = ShareCardTemplateStore()
    private let preferenceStore = UserPreferenceStore()
    private let recommendationEngine = RecommendationEngine()
    private let feedbackCollector = FeedbackCollector()
    private let imageEnhancementService = ImageEnhancementService()
    private let sceneCorrectionStore = SceneCorrectionHistoryStore()
    private let recognitionMetricsLogger = ImageRecognitionMetricsLogger()
    private let imageAnalyzer = ImageAnalyzer()
    private let shareCardRenderer = ShareCardRenderer()

    private var uiLanguage: AppLanguage {
        appLanguageManager.language
    }

    private var isDeveloperDiagnosticsEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SnapCopyTheme.appBackground
                    .ignoresSafeArea()
                SnapCopyLiquidBackdrop()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                GeometryReader { proxy in
                    let contentWidth = min(max(proxy.size.width - 32, 0), 560)
                    let previewHeight = fixedPreviewHeight(for: proxy.size, hasPhoto: selectedImage != nil)

                    VStack(spacing: 12) {
                        if selectedImage == nil {
                            header
                                .frame(width: contentWidth)
                        }

                        fixedPhotoSelectionState(previewHeight: previewHeight)
                            .frame(width: contentWidth)

                        captionActionState
                            .frame(width: contentWidth)

                        ScrollView {
                            VStack(spacing: 18) {
                                scrollableCaptionOptions
                                captionList
                                navigationButtonRow
                            }
                            .frame(width: contentWidth)
                            .padding(.bottom, 18)
                            .frame(maxWidth: .infinity)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .navigationTitle("SnapCopy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        NavigationLink {
                            HistoryView()
                        } label: {
                            Image(systemName: "clock")
                                .toolbarGlassIcon()
                        }
                        .accessibilityLabel(uiLanguage.text(.historyAndFavorites))

                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                                .toolbarGlassIcon()
                        }
                        .accessibilityLabel(uiLanguage.text(.settings))
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    await loadSelectedPhoto(from: newItem)
                }
            }
            .onChange(of: selectedEnhancementPreset) { _ in
                updateEnhancedImage()
            }
            .onChange(of: manualSceneSelection) { _ in
                recordManualSceneCorrectionIfNeeded()
                resetGeneratedCaptions()
                refreshDebugPrompt()
            }
            .onChange(of: selectedPlatform) { platform in
                preferenceStore.updatePreferredPlatform(platform)
                resetGeneratedCaptions()
                refreshDebugPrompt()
            }
            .onChange(of: selectedLengthLevel) { lengthLevel in
                preferenceStore.updatePreferredLengthLevel(lengthLevel)
                resetGeneratedCaptions()
                refreshDebugPrompt()
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(activityItems: payload.activityItems, onComplete: payload.onComplete)
            }
            .sheet(item: $shareDraft) { draft in
                CaptionShareEditView(
                    draft: draft,
                    onCancel: {
                        shareDraft = nil
                    },
                    onConfirm: { finalText, shareMode in
                        prepareShare(from: draft, finalText: finalText, shareMode: shareMode)
                    }
                )
            }
            .sheet(isPresented: $isPaywallPresented) {
                PaywallView()
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraPicker(
                    onImagePicked: { image in
                        isCameraPresented = false
                        Task {
                            await useCapturedPhoto(image)
                        }
                    },
                    onCancel: {
                        isCameraPresented = false
                    }
                )
            }
            .sheet(isPresented: $isImageAnalysisDebugPresented) {
                ImageAnalysisDebugView(
                    analysisResult: imageAnalysisResult,
                    foundationPrompt: currentDebugPrompt,
                    rawFoundationResult: lastFoundationRawResult,
                    latestMetricRecord: recognitionMetricsLogger.loadRecords().first
                )
            }
            .sheet(isPresented: $isRecommendationDebugPresented) {
                RecommendationDebugView(
                    result: lastRecommendationResult,
                    feedbackEvents: recommendationFeedbackEvents
                )
            }
            .alert(item: $pendingTrainingContributionPrompt) { prompt in
                Alert(
                    title: Text(prompt.title),
                    message: Text(prompt.message),
                    primaryButton: .default(Text(prompt.confirmTitle)) {
                        Task {
                            await submitTrainingContribution(prompt)
                        }
                    },
                    secondaryButton: .cancel(Text(prompt.declineTitle)) {
                        declineTrainingContribution(prompt)
                    }
                )
            }
            .onAppear {
                usageLimiter.refreshIfNeeded()
                refreshLocalAIStatus()
                refreshFavoriteState()
                refreshRecommendationFeedbackState()
                let preference = preferenceStore.load()
                selectedPlatform = preference.preferredPlatforms.first ?? .general
                selectedLengthLevel = preference.preferredLengthLevel
            }
            .onChange(of: appLanguageManager.language) { _ in
                refreshLocalAIStatus()
            }
            .overlay(alignment: .bottom) {
                if let copyConfirmationMessage {
                    Text(copyConfirmationMessage)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.78), in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: copyConfirmationMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SnapCopy")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(SnapCopyTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)

                Text(uiLanguage.text(.appSubtitle))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(SnapCopyTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .layoutPriority(1)

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(SnapCopyTheme.primaryGradient)
                    .shadow(color: SnapCopyTheme.rose.opacity(0.24), radius: 14, y: 8)

                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 62, height: 62)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .liquidGlassCard()
    }

    private func fixedPreviewHeight(for size: CGSize, hasPhoto: Bool) -> CGFloat {
        if hasPhoto {
            min(150, max(112, size.height * 0.17))
        } else {
            min(240, max(160, size.height * 0.28))
        }
    }

    private func fixedPhotoSelectionState(previewHeight: CGFloat) -> some View {
        let hasPhoto = previewImage != nil

        return VStack(spacing: hasPhoto ? 10 : 14) {
            if let previewImage {
                SnapCopyPhotoPreview(
                    image: previewImage,
                    accessibilityLabel: uiLanguage.text(.selectedPhotoPreview),
                    height: previewHeight
                )
                photoStylePicker
            } else {
                emptyPhotoState
            }
        }
        .padding(hasPhoto ? 12 : 16)
        .frame(maxWidth: .infinity)
        .liquidGlassCard()
    }

    private var photoStylePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(uiLanguage.text(.photoStyle))
                .font(.footnote)
                .foregroundStyle(SnapCopyTheme.secondaryText)

            Picker(uiLanguage.text(.photoStyle), selection: $selectedEnhancementPreset) {
                ForEach(ImageEnhancementPreset.allCases) { preset in
                    Text(uiLanguage.presetName(preset)).tag(preset)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var captionActionState: some View {
        let isCompact = selectedImage != nil

        VStack(spacing: isCompact ? 12 : 18) {
            if !isCompact {
                Text(uiLanguage.text(.photoIntro))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SnapCopyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isLoadingImage {
                ProgressView(uiLanguage.text(.loadingPhoto))
            }

            if let imageLoadError {
                Text(imageLoadError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            photoSourceHoldHint

            HStack(spacing: 12) {
                SnapCopyHoldActionButton(tint: SnapCopyTheme.rose) {
                    isPhotoPickerPresented = true
                } label: {
                    SnapCopyPhotoSourceButtonLabel(
                        title: uiLanguage.text(.album),
                        systemImage: "photo.on.rectangle.angled",
                        tint: SnapCopyTheme.rose,
                        minHeight: isCompact ? 52 : 64
                    )
                }
                .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhotoItem, matching: .images)
                .accessibilityHint(localizedPhotoSourceHoldHint)

                SnapCopyHoldActionButton(tint: SnapCopyTheme.sage) {
                    presentCamera()
                } label: {
                    SnapCopyPhotoSourceButtonLabel(
                        title: uiLanguage.text(.camera),
                        systemImage: "camera.fill",
                        tint: SnapCopyTheme.sage,
                        minHeight: isCompact ? 52 : 64
                    )
                }
                .accessibilityHint(localizedPhotoSourceHoldHint)
            }

            Button {
                Task {
                    await generateCaptions()
                }
            } label: {
                Label(captions.isEmpty ? uiLanguage.text(.generateCaption) : uiLanguage.text(.regenerate), systemImage: "sparkles")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SnapCopyPrimaryButtonStyle())
            .disabled(selectedImage == nil || isLoadingImage || isUnderstandingImage || isGeneratingCaptions)

            if isCompact {
                HStack(spacing: 10) {
                    Label(captionUsageText, systemImage: entitlementManager.level == .free ? "gauge.with.dots.needle.33percent" : "sparkle")
                    Spacer(minLength: 0)
                    Label(localAIStatusText, systemImage: "cpu")
                }
                .font(.caption)
                .foregroundStyle(SnapCopyTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: entitlementManager.level == .free ? "gauge.with.dots.needle.33percent" : "sparkle")
                    Text(captionUsageText)
                }
                .font(.footnote)
                .foregroundStyle(SnapCopyTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

                VStack(alignment: .leading, spacing: 4) {
                    Label(localAIStatusText, systemImage: "cpu")
                        .font(.footnote)
                        .foregroundStyle(SnapCopyTheme.secondaryText)

                    if !localAIStatusDetail.isEmpty {
                        Text(localAIStatusDetail)
                            .font(.caption)
                            .foregroundStyle(SnapCopyTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(isCompact ? 14 : 20)
        .frame(maxWidth: .infinity)
        .liquidGlassCard()
    }

    @ViewBuilder
    private var scrollableCaptionOptions: some View {
        if selectedImage != nil {
            VStack(spacing: 18) {
                if isDeveloperDiagnosticsEnabled {
                    sceneSelectionState
                }
                platformSelectionState
                lengthSelectionState
                if entitlementManager.level == .pro {
                    creativeImageState
                }
            }
        }
    }

    private var photoSourceHoldHint: some View {
        Label(localizedPhotoSourceHoldHint, systemImage: "hand.point.up.left.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(SnapCopyTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SnapCopyTheme.controlBackground.opacity(0.72), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(SnapCopyTheme.hairline, lineWidth: 1)
            }
            .accessibilityLabel(localizedPhotoSourceHoldHint)
    }

    private var navigationButtonRow: some View {
        HStack(spacing: 12) {
            NavigationLink {
                HistoryView()
            } label: {
                Label(uiLanguage.text(.historyAndFavorites), systemImage: "clock")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SnapCopySecondaryButtonStyle())

            NavigationLink {
                SettingsView()
            } label: {
                Label(uiLanguage.text(.settingsAndPreferences), systemImage: "gearshape")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SnapCopySecondaryButtonStyle())
        }
    }

    private var emptyPhotoState: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(SnapCopyTheme.softPanelGradient)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.62),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 92, height: 92)
                        .overlay {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(.white.opacity(0.78), lineWidth: 1)
                        }
                        .shadow(color: SnapCopyTheme.rose.opacity(0.12), radius: 18, y: 10)

                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 34, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(SnapCopyTheme.rose)
                }

                HStack(spacing: 8) {
                    Image(systemName: "text.quote")
                        .foregroundStyle(SnapCopyTheme.sage)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(SnapCopyTheme.champagne.opacity(0.7))
                        .frame(width: 118, height: 8)
                }
            }
        }
        .frame(height: 190)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .accessibilityLabel(uiLanguage.text(.noPhotoSelected))
    }

    private var sceneSelectionState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(uiLanguage.text(.sceneTitle))
                    .font(.footnote)
                    .foregroundStyle(SnapCopyTheme.secondaryText)

                Spacer()

                Picker(uiLanguage.text(.sceneTitle), selection: $manualSceneSelection) {
                    ForEach(ManualSceneOption.allCases) { option in
                        Text(uiLanguage.manualSceneName(option)).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            if isUnderstandingImage {
                ProgressView(uiLanguage.text(.recognizingScene))
                    .font(.caption)
            } else {
                Text(sceneStatusText)
                    .font(.caption)
                    .foregroundStyle(SnapCopyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if shouldSuggestManualScene {
                Label(shouldRequireManualScene ? localizedSceneMustChooseText : localizedSceneSuggestChooseText, systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(shouldRequireManualScene ? SnapCopyTheme.rose : SnapCopyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isDeveloperDiagnosticsEnabled {
                Button {
                    isImageAnalysisDebugPresented = true
                } label: {
                    Label("照片理解诊断", systemImage: "stethoscope")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SnapCopySecondaryButtonStyle())
            }
        }
        .padding(14)
        .background(SnapCopyTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                .stroke(SnapCopyTheme.hairline, lineWidth: 1)
        }
    }

    private var platformSelectionState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(uiLanguage.text(.platformTitle))
                    .font(.footnote)
                    .foregroundStyle(SnapCopyTheme.secondaryText)

                Spacer()

                Text(uiLanguage.platformName(selectedPlatform))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SnapCopyTheme.rose)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SocialPlatform.allCases) { platform in
                        Button {
                            selectedPlatform = platform
                        } label: {
                            Label(uiLanguage.platformName(platform), systemImage: platform.systemImageName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(platform == selectedPlatform ? .white : SnapCopyTheme.rose)
                                .background(
                                    platform == selectedPlatform ? SnapCopyTheme.rose : SnapCopyTheme.controlBackground,
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(platform == selectedPlatform ? .clear : SnapCopyTheme.hairline, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }

            Text(uiLanguage.text(.platformTemplateNote))
                .font(.caption)
                .foregroundStyle(SnapCopyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(SnapCopyTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                .stroke(SnapCopyTheme.hairline, lineWidth: 1)
        }
    }

    private var lengthSelectionState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(uiLanguage.text(.lengthTitle))
                    .font(.footnote)
                    .foregroundStyle(SnapCopyTheme.secondaryText)

                Spacer()

                Text(uiLanguage.lengthLevelName(selectedLengthLevel))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SnapCopyTheme.rose)
            }

            HStack(spacing: 8) {
                ForEach(LengthLevel.allCases) { lengthLevel in
                    Button {
                        selectedLengthLevel = lengthLevel
                    } label: {
                        Label(uiLanguage.lengthLevelName(lengthLevel), systemImage: lengthLevel.systemImageName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .foregroundStyle(lengthLevel == selectedLengthLevel ? .white : SnapCopyTheme.rose)
                            .background(
                                lengthLevel == selectedLengthLevel ? SnapCopyTheme.rose : SnapCopyTheme.controlBackground,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(lengthLevel == selectedLengthLevel ? .clear : SnapCopyTheme.hairline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(uiLanguage.text(.lengthTemplateNote))
                .font(.caption)
                .foregroundStyle(SnapCopyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(SnapCopyTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                .stroke(SnapCopyTheme.hairline, lineWidth: 1)
        }
    }

    private var creativeImageState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(uiLanguage.text(.plusCreativeImageTitle))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SnapCopyTheme.primaryText)

                    Text(uiLanguage.text(.plusCreativeImageSubtitle))
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text("Pro")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(SnapCopyTheme.primaryGradient, in: Capsule())
            }

            HStack(spacing: 8) {
                ForEach(CreativeImageStyle.allCases) { style in
                    Button {
                        selectedCreativeImageStyle = style
                    } label: {
                        Label(uiLanguage.creativeImageStyleName(style), systemImage: style.systemImageName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 8)
                            .foregroundStyle(style == selectedCreativeImageStyle ? .white : SnapCopyTheme.rose)
                            .background(
                                style == selectedCreativeImageStyle ? SnapCopyTheme.rose : SnapCopyTheme.controlBackground,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(style == selectedCreativeImageStyle ? .clear : SnapCopyTheme.hairline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                }
            }
            .opacity(0.58)

            Text(uiLanguage.creativeImageStyleDescription(selectedCreativeImageStyle))
                .font(.caption)
                .foregroundStyle(SnapCopyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Label(uiLanguage.text(.creativeImageProReserved), systemImage: "lock")
                .font(.caption)
                .foregroundStyle(SnapCopyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    await generateCreativeImage()
                }
            } label: {
                Label(uiLanguage.text(.generateCreativeImage), systemImage: "wand.and.sparkles")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SnapCopyPrimaryButtonStyle())
            .disabled(true)
        }
        .padding(14)
        .background(SnapCopyTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                .stroke(SnapCopyTheme.hairline, lineWidth: 1)
        }
    }

    private var captionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isGeneratingCaptions {
                ProgressView(uiLanguage.text(.generatingCaption))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let captionGenerationError {
                Text(captionGenerationError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            if !captions.isEmpty {
                captionSectionHeader

                if let activeCaptionBinding {
                    CaptionCardView(
                        candidate: activeCaptionBinding,
                        isFavorite: isFavorite(activeCaptionBinding.wrappedValue),
                        onCopy: copyCaption,
                        onShare: shareCaption,
                        onToggleFavorite: toggleFavorite,
                        onDislike: dislikeCaption
                    )
                }

                cloudEnhancementState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var captionSectionHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                captionSectionTitle

                Spacer(minLength: 8)

                generationModeBadge
                recommendationDebugButton
            }

            VStack(alignment: .leading, spacing: 8) {
                captionSectionTitle
                HStack(spacing: 8) {
                    generationModeBadge
                    recommendationDebugButton
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    private var captionSectionTitle: some View {
        Text(uiLanguage.text(.generatedCaptionsTitle))
            .font(.headline.weight(.semibold))
            .foregroundStyle(SnapCopyTheme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .layoutPriority(1)
    }

    @ViewBuilder
    private var generationModeBadge: some View {
        if let lastGenerationMode {
            Text(uiLanguage.generationModeLine(lastGenerationMode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(SnapCopyTheme.sage)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(SnapCopyTheme.sage.opacity(0.12), in: Capsule())
                .layoutPriority(0)
        }
    }

    @ViewBuilder
    private var recommendationDebugButton: some View {
        if isDeveloperDiagnosticsEnabled {
            Button {
                refreshRecommendationFeedbackState()
                isRecommendationDebugPresented = true
            } label: {
                Label("推荐调试", systemImage: "chart.line.uptrend.xyaxis")
                    .labelStyle(.iconOnly)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SnapCopyTheme.rose)
                    .frame(width: 34, height: 30)
                    .background(SnapCopyTheme.rose.opacity(0.11), in: Capsule())
            }
            .accessibilityLabel("推荐调试")
        }
    }

    @ViewBuilder
    private var cloudEnhancementState: some View {
        if canShowCloudEnhancementEntry {
            VStack(alignment: .leading, spacing: 8) {
                if isCloudEnhancingCaptions {
                    CloudEnhancementWaitingView(
                        phase: cloudEnhancementPhase,
                        language: uiLanguage
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                if let cloudEnhancementStatusMessage {
                    Text(cloudEnhancementStatusMessage)
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let contributionStatusMessage {
                    Text(contributionStatusMessage)
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let cloudEnhancementError {
                    Text(cloudEnhancementError)
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.rose)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task {
                        await handleCloudEnhancementButtonTap()
                    }
                } label: {
                    Label(localizedCloudEnhanceButtonText, systemImage: "sparkles.rectangle.stack")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SnapCopySecondaryButtonStyle())
                .disabled(isCloudEnhancingCaptions || isGeneratingCaptions || cloudBackendRemainingQuota == 0)

                Text(localizedCloudEnhanceQuotaText)
                    .font(.caption)
                    .foregroundStyle(SnapCopyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(SnapCopyTheme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                    .stroke(SnapCopyTheme.hairline, lineWidth: 1)
            }
        }
    }

    private var previewImage: UIImage? {
        enhancedImage ?? selectedImage
    }

    private var activeCaptionBinding: Binding<CaptionCandidate>? {
        guard captions.indices.contains(currentCaptionIndex) else {
            return nil
        }

        return Binding {
            captions[currentCaptionIndex]
        } set: { updatedCaption in
            captions[currentCaptionIndex] = updatedCaption
        }
    }

    private var captionUsageText: String {
        uiLanguage.captionUsageText(level: entitlementManager.level, used: usageLimiter.record.captionGenerations)
    }

    private var canShowCloudEnhancementEntry: Bool {
        CloudFeatureFlags.cloudEnhancedCaptions && cloudEnhancementService.isEnabled
    }

    private var isCloudEnhancementEnabled: Bool {
        CloudFeatureFlags.cloudEnhancementEnabled
    }

    private var localizedCloudEnhancementBusyText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "云端增强暂时繁忙"
        case .english:
            return "Cloud enhancement is temporarily busy"
        case .japanese:
            return "クラウド強化は一時的に混み合っています"
        case .traditionalChinese:
            return "雲端增強暫時繁忙"
        }
    }

    private var localizedCloudEnhanceQuotaText: String {
        let remaining = cloudBackendRemainingQuota

        switch uiLanguage {
        case .simplifiedChinese:
            return "测试版云端增强：\(remaining.map { "后端剩余 \($0) 次" } ?? "额度将由后端同步")。增强时会上传压缩照片做云端理解，不保存原图。"
        case .english:
            return "Beta cloud enhancement: \(remaining.map { "\($0) left on backend" } ?? "quota syncs from backend"). A compressed photo is sent for cloud understanding and the original is not stored."
        case .japanese:
            return "ベータ版クラウド強化：\(remaining.map { "バックエンド残り \($0) 回" } ?? "回数はバックエンドから同期されます")。クラウド理解のため圧縮写真を送信し、元画像は保存しません。"
        case .traditionalChinese:
            return "測試版雲端增強：\(remaining.map { "後端剩餘 \($0) 次" } ?? "額度將由後端同步")。增強時會上傳壓縮照片做雲端理解，不保存原圖。"
        }
    }

    private var localizedCloudEnhanceButtonText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "增强生成"
        case .english:
            return "Enhance captions"
        case .japanese:
            return "文案を強化"
        case .traditionalChinese:
            return "增強生成"
        }
    }

    private var localizedCloudEnhancingText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "正在理解照片并增强文案…"
        case .english:
            return "Understanding the photo and enhancing captions..."
        case .japanese:
            return "写真を理解して文案を強化しています…"
        case .traditionalChinese:
            return "正在理解照片並增強文案…"
        }
    }

    private var captionContext: CaptionGenerationContext {
        CaptionGenerationContext(
            analysisResult: imageAnalysisResult,
            manualScene: isDeveloperDiagnosticsEnabled ? manualSceneSelection : .auto
        )
    }

    private var currentDebugPrompt: String {
        if !lastFoundationPrompt.isEmpty {
            return lastFoundationPrompt
        }

        let prompt = CaptionGenerationPromptBuilder().makePrompt(
            context: captionContext,
            preference: currentGenerationPreference
        )
        return prompt.prompt
    }

    private var currentGenerationPreference: UserPreference {
        var preference = preferenceStore.load()
        preference.setPreferredPlatforms([selectedPlatform])
        preference.setPreferredLengthLevel(selectedLengthLevel)
        return preference
    }

    private var sceneConfidence: Double? {
        imageAnalysisResult?.sceneResolution.confidence
    }

    private var shouldSuggestManualScene: Bool {
        guard manualSceneSelection == .auto,
              let sceneConfidence,
              selectedImage != nil else {
            return false
        }

        return sceneConfidence < 0.75
    }

    private var shouldRequireManualScene: Bool {
        guard manualSceneSelection == .auto,
              let sceneConfidence,
              selectedImage != nil else {
            return false
        }

        return sceneConfidence < 0.45
    }

    private var sceneStatusText: String {
        if manualSceneSelection != .auto {
            return localizedManualSceneStatus
        }

        if let imageUnderstandingError {
            return imageUnderstandingError
        }

        guard let imageUnderstandingResult else {
            return localizedAutoSceneHint
        }

        if let imageAnalysisResult {
            let resolved = imageAnalysisResult.sceneResolution
            let confidence = Int((resolved.confidence * 100).rounded())
            let subScene = resolved.subScene.map { " / \($0)" } ?? ""
            return "App scene: \(resolved.scene.displayName)\(subScene)，confidence \(confidence)%。\(localizedSceneDetailText(imageUnderstandingResult))"
        }

        if imageUnderstandingResult.sceneTags.isEmpty {
            if let statusSummary = localizedStatusSummary(for: imageUnderstandingResult) {
                return localizedDetailsOnlyStatus(statusSummary)
            }

            return localizedNoClearSceneStatus
        }

        let tags = imageUnderstandingResult.sceneTags.joined(separator: localizedListSeparator)

        if let statusSummary = localizedStatusSummary(for: imageUnderstandingResult) {
            return localizedSceneStatus(tags: tags, details: statusSummary)
        }

        return localizedSceneStatus(tags: tags, details: nil)
    }

    private func localizedSceneDetailText(_ result: ImageUnderstandingResult) -> String {
        if result.sceneTags.isEmpty {
            return localizedStatusSummary(for: result) ?? ""
        }

        let tags = result.sceneTags.joined(separator: localizedListSeparator)
        if let statusSummary = localizedStatusSummary(for: result) {
            return " \(tags)。\(statusSummary)"
        }

        return " \(tags)。"
    }

    private var localizedManualSceneStatus: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "将使用手动场景：\(uiLanguage.manualSceneName(manualSceneSelection))。"
        case .english:
            return "Manual scene: \(uiLanguage.manualSceneName(manualSceneSelection))."
        case .japanese:
            return "手動シーン：\(uiLanguage.manualSceneName(manualSceneSelection))。"
        case .traditionalChinese:
            return "將使用手動場景：\(uiLanguage.manualSceneName(manualSceneSelection))。"
        }
    }

    private var localizedAutoSceneHint: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "选择照片后会自动识别场景。"
        case .english:
            return "The scene will be recognized after you choose a photo."
        case .japanese:
            return "写真を選ぶとシーンを自動認識します。"
        case .traditionalChinese:
            return "選擇照片後會自動識別場景。"
        }
    }

    private var localizedNoClearSceneStatus: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "暂未识别到明确场景，可以手动选择一个场景。"
        case .english:
            return "No clear scene was recognized yet. You can choose one manually."
        case .japanese:
            return "明確なシーンはまだ認識できません。手動で選ぶこともできます。"
        case .traditionalChinese:
            return "暫未識別到明確場景，可以手動選擇一個場景。"
        }
    }

    private var localizedListSeparator: String {
        switch uiLanguage {
        case .english:
            return ", "
        case .simplifiedChinese, .japanese, .traditionalChinese:
            return "、"
        }
    }

    private var localizedPhotoSourceHoldHint: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "按住 0.3 秒打开相册或相机"
        case .english:
            return "Hold for 0.3s to open Photos or Camera"
        case .japanese:
            return "0.3秒長押しで写真またはカメラを開く"
        case .traditionalChinese:
            return "按住 0.3 秒打開相簿或相機"
        }
    }

    private func localizedDetailsOnlyStatus(_ details: String) -> String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "已识别图片细节：\(details)。可以手动补充场景。"
        case .english:
            return "Recognized details: \(details). You can add a scene manually."
        case .japanese:
            return "写真の詳細：\(details)。必要なら手動でシーンを追加できます。"
        case .traditionalChinese:
            return "已識別圖片細節：\(details)。可以手動補充場景。"
        }
    }

    private func localizedSceneStatus(tags: String, details: String?) -> String {
        switch (uiLanguage, details) {
        case (.simplifiedChinese, .some(let details)):
            return "识别到：\(tags)。细节：\(details)。"
        case (.simplifiedChinese, .none):
            return "识别到：\(tags)。"
        case (.english, .some(let details)):
            return "Recognized: \(tags). Details: \(details)."
        case (.english, .none):
            return "Recognized: \(tags)."
        case (.japanese, .some(let details)):
            return "認識：\(tags)。詳細：\(details)。"
        case (.japanese, .none):
            return "認識：\(tags)。"
        case (.traditionalChinese, .some(let details)):
            return "識別到：\(tags)。細節：\(details)。"
        case (.traditionalChinese, .none):
            return "識別到：\(tags)。"
        }
    }

    private func localizedStatusSummary(for result: ImageUnderstandingResult) -> String? {
        var parts: [String] = []

        if !result.detectedTexts.isEmpty {
            switch uiLanguage {
            case .simplifiedChinese:
                parts.append("文字：\(result.detectedTexts.prefix(2).joined(separator: "、"))")
            case .english:
                parts.append("text: \(result.detectedTexts.prefix(2).joined(separator: ", "))")
            case .japanese:
                parts.append("文字：\(result.detectedTexts.prefix(2).joined(separator: "、"))")
            case .traditionalChinese:
                parts.append("文字：\(result.detectedTexts.prefix(2).joined(separator: "、"))")
            }
        }

        if let traitsSummary = localizedVisualTraitsStatus(result.visualTraits) {
            parts.append(traitsSummary)
        }

        guard !parts.isEmpty else {
            return nil
        }

        let separator = uiLanguage == .english ? "; " : "；"
        return parts.joined(separator: separator)
    }

    private func localizedVisualTraitsStatus(_ traits: ImageVisualTraits) -> String? {
        guard traits.hasUsefulContext else {
            return nil
        }

        var parts: [String] = []

        if traits.brightness != .unknown {
            parts.append(localizedBrightnessName(traits.brightness))
        }

        if traits.colorTemperature != .unknown {
            parts.append(localizedColorTemperatureName(traits.colorTemperature))
        }

        if traits.saturation != .unknown {
            parts.append(localizedSaturationName(traits.saturation))
        }

        if traits.aspect != .unknown {
            parts.append(localizedAspectName(traits.aspect))
        }

        if !traits.dominantColors.isEmpty {
            parts.append(traits.dominantColors.prefix(3).joined(separator: localizedListSeparator))
        }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.joined(separator: localizedListSeparator)
    }

    private func localizedBrightnessName(_ brightness: ImageBrightness) -> String {
        switch (uiLanguage, brightness) {
        case (.english, .dark): return "dark"
        case (.english, .dim): return "low light"
        case (.english, .balanced): return "balanced light"
        case (.english, .bright): return "bright"
        case (.japanese, .dark): return "暗め"
        case (.japanese, .dim): return "低照度"
        case (.japanese, .balanced): return "光が均一"
        case (.japanese, .bright): return "明るい"
        case (.traditionalChinese, .dark): return "暗調"
        case (.traditionalChinese, .dim): return "低光"
        case (.traditionalChinese, .balanced): return "光線均衡"
        case (.traditionalChinese, .bright): return "明亮"
        default: return brightness.displayName
        }
    }

    private func localizedColorTemperatureName(_ temperature: ImageColorTemperature) -> String {
        switch (uiLanguage, temperature) {
        case (.english, .warm): return "warm tone"
        case (.english, .neutral): return "neutral tone"
        case (.english, .cool): return "cool tone"
        case (.japanese, .warm): return "暖色"
        case (.japanese, .neutral): return "自然な色"
        case (.japanese, .cool): return "寒色"
        case (.traditionalChinese, .warm): return "暖色"
        case (.traditionalChinese, .neutral): return "自然色"
        case (.traditionalChinese, .cool): return "冷色"
        default: return temperature.displayName
        }
    }

    private func localizedSaturationName(_ saturation: ImageSaturation) -> String {
        switch (uiLanguage, saturation) {
        case (.english, .muted): return "muted"
        case (.english, .natural): return "natural saturation"
        case (.english, .vivid): return "vivid"
        case (.japanese, .muted): return "低彩度"
        case (.japanese, .natural): return "自然な彩度"
        case (.japanese, .vivid): return "鮮やか"
        case (.traditionalChinese, .muted): return "低飽和"
        case (.traditionalChinese, .natural): return "自然飽和"
        case (.traditionalChinese, .vivid): return "高飽和"
        default: return saturation.displayName
        }
    }

    private func localizedAspectName(_ aspect: ImageAspect) -> String {
        switch (uiLanguage, aspect) {
        case (.english, .portrait): return "portrait"
        case (.english, .landscape): return "landscape"
        case (.english, .square): return "square"
        case (.japanese, .portrait): return "縦長"
        case (.japanese, .landscape): return "横長"
        case (.japanese, .square): return "正方形"
        case (.traditionalChinese, .portrait): return "直圖"
        case (.traditionalChinese, .landscape): return "橫圖"
        case (.traditionalChinese, .square): return "方圖"
        default: return aspect.displayName
        }
    }

    @MainActor
    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        let imageRequest = prepareForNewImageSelection(isLoading: true)

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                guard imageSelectionID == imageRequest.selectionID else {
                    return
                }

                selectedImage = image
                selectedEnhancementPreset = .natural
                updateEnhancedImage()
                isLoadingImage = false
                await analyzeSelectedImage(image, requestID: imageRequest.understandingRequestID)
            } else {
                guard imageSelectionID == imageRequest.selectionID else {
                    return
                }

                selectedImage = nil
                enhancedImage = nil
                imageUnderstandingResult = nil
                imageLoadError = localizedPhotoLoadFailedText
                isLoadingImage = false
            }
        } catch {
            guard imageSelectionID == imageRequest.selectionID else {
                return
            }

            selectedImage = nil
            enhancedImage = nil
            imageUnderstandingResult = nil
            imageLoadError = localizedPhotoLoadFailedText
            isLoadingImage = false
        }
    }

    @MainActor
    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            imageLoadError = localizedCameraUnavailableText
            return
        }

        imageLoadError = nil
        isCameraPresented = true
    }

    @MainActor
    private func useCapturedPhoto(_ image: UIImage) async {
        selectedPhotoItem = nil
        let imageRequest = prepareForNewImageSelection(isLoading: false)

        selectedImage = image
        selectedEnhancementPreset = .natural
        updateEnhancedImage()
        await analyzeSelectedImage(image, requestID: imageRequest.understandingRequestID)
    }

    @MainActor
    private func prepareForNewImageSelection(isLoading: Bool) -> ImageSelectionRequest {
        let selectionID = UUID()
        let understandingRequestID = UUID()

        imageSelectionID = selectionID
        imageUnderstandingRequestID = understandingRequestID
        captionGenerationRequestID = UUID()
        isLoadingImage = isLoading
        isGeneratingCaptions = false
        imageLoadError = nil
        captionGenerationError = nil
        cloudEnhancementError = nil
        cloudEnhancementStatusMessage = nil
        contributionStatusMessage = nil
        pendingTrainingContributionPrompt = nil
        resetGeneratedCaptions()
        imageAnalysisResult = nil
        imageUnderstandingResult = nil
        imageUnderstandingError = nil
        isUnderstandingImage = false
        manualSceneSelection = .auto
        isGeneratingCreativeImage = false
        creativeImage = nil
        creativeImageError = nil
        creativeImageStatusMessage = nil
        lastFoundationPrompt = ""
        lastFoundationRawResult = ""

        return ImageSelectionRequest(selectionID: selectionID, understandingRequestID: understandingRequestID)
    }

    @MainActor
    private func generateCaptions() async {
        guard let selectedImage else {
            captionGenerationError = localizedSelectPhotoFirstText
            return
        }

        guard !isUnderstandingImage else {
            captionGenerationError = localizedSceneStillRecognizingText
            return
        }

        guard !isDeveloperDiagnosticsEnabled || !shouldRequireManualScene else {
            captionGenerationError = localizedSceneMustChooseText
            return
        }

        guard usageLimiter.canGenerateCaption(for: entitlementManager.level) else {
            captionGenerationError = nil
            isPaywallPresented = true
            return
        }

        let generationID = UUID()
        let generationImageID = imageSelectionID
        let generationContext = captionContext
        captionGenerationRequestID = generationID
        isGeneratingCaptions = true
        captionGenerationError = nil
        cloudEnhancementError = nil
        cloudEnhancementStatusMessage = nil

        do {
            refreshLocalAIStatus()
            let preference = currentGenerationPreference
            let debugPrompt = CaptionGenerationPromptBuilder().makePrompt(context: generationContext, preference: preference)
            lastFoundationPrompt = debugPrompt.prompt
            lastFoundationRawResult = ""
            let generationResult = try await captionService.generateCaptions(
                for: selectedImage,
                context: generationContext,
                preference: preference
            )
            guard captionGenerationRequestID == generationID, imageSelectionID == generationImageID else {
                return
            }

            let recentFeedback = preferenceStore.loadRecommendationFeedbackEvents()
            let recommendationResult = recommendationEngine.recommend(
                candidates: generationResult.candidates,
                context: generationContext,
                targetPlatform: selectedPlatform,
                preference: preference.recommendationProfile,
                recentFeedback: recentFeedback,
                targetLanguage: preference.preferredCaptionLanguage
            )

            lastRecommendationResult = recommendationResult
            recommendationFeedbackEvents = recommendationResult.recentFeedback
            captions = ratingStore.applySavedRatings(to: recommendationResult.candidates)
            currentCaptionIndex = 0
            resetCaptionDwellTimer()
            lastGenerationMode = generationResult.mode
            lastGenerationStatusMessage = generationResult.statusMessage
            if let debugInfo = generationResult.debugInfo {
                lastFoundationPrompt = debugInfo.foundationPrompt
                lastFoundationRawResult = debugInfo.rawFoundationResult
            }

            if selectedEnhancementPreset != recommendationResult.recommendedFilter.preset {
                selectedEnhancementPreset = recommendationResult.recommendedFilter.preset
                updateEnhancedImage()
            }

            historyStore.saveGeneratedCandidates(captions, image: previewImage ?? selectedImage)
            refreshFavoriteState()
            usageLimiter.recordCaptionGeneration(for: entitlementManager.level)
        } catch {
            guard captionGenerationRequestID == generationID, imageSelectionID == generationImageID else {
                return
            }

            captions = []
            lastGenerationMode = nil
            lastGenerationStatusMessage = nil
            captionGenerationError = localizedGenerationFailedText
        }

        if captionGenerationRequestID == generationID {
            isGeneratingCaptions = false
        }
    }

    @MainActor
    private func handleCloudEnhancementButtonTap() async {
        guard isCloudEnhancementEnabled else {
            cloudEnhancementStatusMessage = nil
            cloudEnhancementError = localizedCloudEnhancementBusyText
            return
        }

        await enhanceCaptionsWithCloud()
    }

    @MainActor
    private func enhanceCaptionsWithCloud() async {
        guard !isCloudEnhancingCaptions else {
            return
        }

        guard isCloudEnhancementEnabled else {
            cloudEnhancementStatusMessage = nil
            cloudEnhancementError = localizedCloudEnhancementBusyText
            return
        }

        guard !captions.isEmpty else {
            cloudEnhancementError = localizedCloudNeedLocalCaptionsText
            return
        }

        guard cloudBackendRemainingQuota != 0 else {
            cloudEnhancementError = localizedCloudQuotaExceededText
            return
        }

        isCloudEnhancingCaptions = true
        cloudEnhancementError = nil
        cloudEnhancementStatusMessage = nil
        updateCloudEnhancementPhase(.preparing)
        defer {
            withAnimation(.easeInOut(duration: 0.22)) {
                isCloudEnhancingCaptions = false
                cloudEnhancementPhase = .idle
            }
        }

        let generationContext = captionContext
        let preference = currentGenerationPreference
        let sceneJson = CaptionGenerationPromptBuilder()
            .makePrompt(context: generationContext, preference: preference, detail: .compact)
            .contextJSON
        let preferenceJson = String(
            data: (try? JSONEncoder().encode(preference.cloudPreferenceSnapshot)) ?? Data(),
            encoding: .utf8
        )
        let cloudRequestID = UUID()
        updateCloudEnhancementPhase(.understandingPhoto)
        let cloudSceneEnhancement = await cloudEnhancedSceneJson(
            baseSceneJson: sceneJson,
            preferenceJson: preferenceJson,
            requestID: cloudRequestID,
            preference: preference
        )
        let request = CloudEnhancementRequestBuilder().makeRequest(
            appUserId: userIdentityManager.appUserId,
            requestId: cloudSceneEnhancement.captionRequestID,
            plan: entitlementManager.level,
            featureType: .captionDeepUnderstanding,
            sceneJson: cloudSceneEnhancement.sceneJson,
            userPreferenceJson: preferenceJson,
            imageUploadEnabled: false,
            locale: preference.preferredCaptionLanguage.rawValue,
            targetPlatform: selectedPlatform
        )

        do {
            updateCloudEnhancementPhase(.writingCaptions)
            let response = try await cloudEnhancementService.enhanceCaptions(request: request)
            let cloudCandidates = makeCloudCandidates(from: response, context: generationContext)

            guard !cloudCandidates.isEmpty else {
                throw CloudEnhancementError.invalidResponse
            }

            updateCloudEnhancementPhase(.arrangingResults)
            let recommendationResult = recommendationEngine.recommend(
                candidates: cloudCandidates,
                context: generationContext,
                targetPlatform: selectedPlatform,
                preference: preference.recommendationProfile,
                recentFeedback: preferenceStore.loadRecommendationFeedbackEvents(),
                targetLanguage: preference.preferredCaptionLanguage
            )

            lastRecommendationResult = recommendationResult
            recommendationFeedbackEvents = recommendationResult.recentFeedback
            captions = ratingStore.applySavedRatings(to: recommendationResult.candidates)
            currentCaptionIndex = 0
            resetCaptionDwellTimer()
            lastGenerationMode = .cloudEnhanced
            lastGenerationStatusMessage = "Cloud enhancement via \(response.provider) / \(response.model)."
            lastFoundationRawResult = response.captions.joined(separator: "\n")
            cloudBackendRemainingQuota = response.remainingQuota
            cloudEnhancementStatusMessage = localizedCloudEnhanceSuccessText(provider: response.provider, remainingQuota: response.remainingQuota)
            historyStore.saveGeneratedCandidates(captions, image: previewImage ?? selectedImage)
            refreshFavoriteState()
            queuePhotoTrainingContribution(
                sceneJson: cloudSceneEnhancement.sceneJson,
                context: generationContext,
                preference: preference,
                source: .cloudEnhancement
            )
        } catch CloudEnhancementError.quotaExceeded {
            cloudBackendRemainingQuota = 0
            cloudEnhancementError = localizedCloudQuotaExceededText
        } catch {
            #if DEBUG
            cloudEnhancementError = "\(localizedCloudEnhanceFailedText)\n\(error.localizedDescription)"
            #else
            cloudEnhancementError = localizedCloudEnhanceFailedText
            #endif
        }
    }

    private func updateCloudEnhancementPhase(_ phase: CloudEnhancementPhase) {
        withAnimation(.easeInOut(duration: 0.24)) {
            cloudEnhancementPhase = phase
        }
    }

    @MainActor
    private func cloudEnhancedSceneJson(
        baseSceneJson: String,
        preferenceJson: String?,
        requestID: UUID,
        preference: UserPreference
    ) async -> CloudSceneEnhancementResult {
        guard CloudFeatureFlags.cloudImageUnderstanding,
              let selectedImage,
              let imagePayload = makeCloudVisionImagePayload(from: selectedImage) else {
            return CloudSceneEnhancementResult(sceneJson: baseSceneJson, captionRequestID: requestID)
        }

        let request = CloudEnhancementRequestBuilder().makeImageUnderstandingRequest(
            appUserId: userIdentityManager.appUserId,
            requestId: requestID,
            plan: entitlementManager.level,
            sceneJson: baseSceneJson,
            userPreferenceJson: preferenceJson,
            imageBase64: imagePayload.base64,
            imageMimeType: imagePayload.mimeType,
            locale: preference.preferredCaptionLanguage.rawValue,
            targetPlatform: selectedPlatform
        )

        do {
            let response = try await cloudEnhancementService.enhanceImageUnderstanding(request: request)
            return CloudSceneEnhancementResult(sceneJson: response.sceneJson, captionRequestID: UUID())
        } catch {
            return CloudSceneEnhancementResult(sceneJson: baseSceneJson, captionRequestID: UUID())
        }
    }

    private func makeCloudVisionImagePayload(from image: UIImage) -> CloudVisionImagePayload? {
        let resizedImage = resizedForCloudVision(image, maxDimension: 1024)
        var compression: CGFloat = 0.78

        while compression >= 0.48 {
            if let data = resizedImage.jpegData(compressionQuality: compression),
               data.count <= 1_100_000 {
                return CloudVisionImagePayload(
                    base64: data.base64EncodedString(),
                    mimeType: "image/jpeg"
                )
            }

            compression -= 0.1
        }

        guard let fallbackData = resizedForCloudVision(image, maxDimension: 768).jpegData(compressionQuality: 0.48),
              fallbackData.count <= 1_100_000 else {
            return nil
        }

        return CloudVisionImagePayload(
            base64: fallbackData.base64EncodedString(),
            mimeType: "image/jpeg"
        )
    }

    private func resizedForCloudVision(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return image
        }

        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else {
            return image
        }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func makeCloudCandidates(
        from response: CloudEnhancementResponse,
        context: CaptionGenerationContext
    ) -> [CaptionCandidate] {
        let styles: [CaptionStyle] = [.premium, .daily, .healing, .humor, .xiaohongshu]
        return response.captions.prefix(5).enumerated().compactMap { index, text in
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                return nil
            }

            return CaptionCandidate(
                text: trimmedText,
                style: styles[index % styles.count],
                platform: selectedPlatform,
                lengthLevel: selectedLengthLevel,
                emojiLevel: .light,
                scene: context.primaryScene
            )
        }
    }

    @MainActor
    private func copyCaption(_ caption: CaptionCandidate) {
        saveBehaviorFeedback(
            for: caption,
            rating: 4,
            recommendationAction: .copyCaption,
            dwellSeconds: currentCaptionDwellSeconds(for: caption)
        )
        historyStore.recordInteraction(for: caption, image: previewImage, interaction: .copied)
        refreshFavoriteState()
        UIPasteboard.general.string = caption.text
        showTransientMessage(uiLanguage.text(.copied))
    }

    @MainActor
    private func shareCaption(_ caption: CaptionCandidate) {
        shareDraft = CaptionShareDraft(
            caption: caption,
            image: previewImage,
            dwellSeconds: currentCaptionDwellSeconds(for: caption)
        )
    }

    @MainActor
    private func prepareShare(from draft: CaptionShareDraft, finalText: String, shareMode: CaptionShareMode) {
        let trimmedText = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            showTransientMessage(uiLanguage.text(.finalCaptionEmpty))
            return
        }

        shareDraft = nil

        let editSummary = CaptionEditSummary(originalText: draft.caption.text, finalText: trimmedText)
        let finalCaption = draft.caption
            .withText(trimmedText)
            .withLengthLevel(editSummary.wasEdited ? inferredLengthLevel(for: trimmedText) : draft.caption.lengthLevel)
        let imageForHistory = draft.image
        let dwellSeconds = draft.dwellSeconds
        let shareContext = captionContext
        let sharePreference = currentGenerationPreference
        let shareCompletion: (Bool) -> Void = { completed in
            guard completed else {
                return
            }

            Task { @MainActor in
                saveBehaviorFeedback(
                    for: finalCaption,
                    rating: 5,
                    recommendationAction: editSummary.wasEdited ? .editedFinalCaptionUsed : .shareCaption,
                    dwellSeconds: dwellSeconds,
                    editSummary: editSummary.wasEdited ? editSummary : nil
                )
                captionSampleStore.recordSharedCaption(
                    original: draft.caption,
                    finalCaption: finalCaption,
                    context: shareContext,
                    preference: sharePreference,
                    editSummary: editSummary
                )
                historyStore.recordInteraction(for: finalCaption, image: imageForHistory, interaction: .shared)
                refreshFavoriteState()
                queueCaptionTrainingContribution(
                    finalCaption: finalCaption,
                    editSummary: editSummary,
                    context: shareContext,
                    preference: sharePreference,
                    source: .share
                )
            }
        }

        guard let imageForHistory else {
            presentSharePayload(SharePayload(activityItems: [trimmedText], onComplete: shareCompletion))
            return
        }

        UIPasteboard.general.string = trimmedText
        showTransientMessage(uiLanguage.text(.shareCaptionCopied))

        do {
            let imageToShare: UIImage
            switch shareMode {
            case .captionCard:
                imageToShare = shareCardRenderer.render(
                    image: imageForHistory,
                    caption: trimmedText,
                    template: shareCardTemplateStore.load()
                )
            case .photoWithCaption:
                imageToShare = imageForHistory
            }

            let shareFiles = try makeShareFileURLs(caption: trimmedText, image: imageToShare)
            presentSharePayload(SharePayload(activityItems: [
                SnapCopyShareTextItemSource(caption: trimmedText, captionURL: shareFiles.captionURL),
                SnapCopyShareImageItemSource(image: imageToShare, imageURL: shareFiles.imageURL)
            ], onComplete: shareCompletion))
        } catch {
            presentSharePayload(SharePayload(activityItems: [trimmedText, imageForHistory], onComplete: shareCompletion))
        }
    }

    @MainActor
    private func presentSharePayload(_ payload: SharePayload) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            sharePayload = payload
        }
    }

    private func inferredLengthLevel(for text: String) -> LengthLevel {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cjkCount = trimmedText.unicodeScalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
        .count

        if cjkCount >= 2 {
            switch cjkCount {
            case 0...22:
                return .short
            case 65...:
                return .long
            default:
                return .medium
            }
        }

        let wordCount = trimmedText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        switch wordCount {
        case 0...18:
            return .short
        case 42...:
            return .long
        default:
            return .medium
        }
    }

    @MainActor
    private func generateCreativeImage() async {
        creativeImage = nil
        creativeImageError = uiLanguage.text(.creativeImageProReserved)
        creativeImageStatusMessage = nil
        showTransientMessage(uiLanguage.text(.creativeImageProReserved))
    }

    @MainActor
    private func shareCreativeImage() {
        guard let creativeImage else {
            return
        }

        sharePayload = SharePayload(activityItems: [creativeImage], onComplete: nil)
    }

    @MainActor
    private func dislikeCaption(_ caption: CaptionCandidate) {
        saveBehaviorFeedback(
            for: caption,
            rating: 1,
            recommendationAction: .regenerate,
            dwellSeconds: currentCaptionDwellSeconds(for: caption)
        )
        showTransientMessage(uiLanguage.text(.disliked))

        if captions.indices.contains(currentCaptionIndex + 1) {
            currentCaptionIndex += 1
            resetCaptionDwellTimer()
            return
        }

        Task {
            await generateCaptions()
        }
    }

    @MainActor
    private func toggleFavorite(_ caption: CaptionCandidate) {
        let isNowFavorite = historyStore.toggleFavorite(for: caption, image: previewImage)
        saveBehaviorFeedback(
            for: caption,
            rating: isNowFavorite ? 4 : nil,
            recommendationAction: isNowFavorite ? .saveCaption : .deleteCaption,
            dwellSeconds: currentCaptionDwellSeconds(for: caption)
        )
        refreshFavoriteState()
        showTransientMessage(uiLanguage.text(isNowFavorite ? .savedToFavorites : .removedFromFavorites))
    }

    private func isFavorite(_ caption: CaptionCandidate) -> Bool {
        favoriteCaptionKeys.contains(CaptionHistoryStore.key(for: caption.text))
    }

    @MainActor
    private func refreshFavoriteState() {
        favoriteCaptionKeys = historyStore.favoriteCaptionKeys()
    }

    @MainActor
    private func refreshRecommendationFeedbackState() {
        recommendationFeedbackEvents = preferenceStore.loadRecommendationFeedbackEvents()
    }

    @MainActor
    private func refreshDebugPrompt() {
        guard selectedImage != nil else {
            lastFoundationPrompt = ""
            return
        }

        lastFoundationPrompt = CaptionGenerationPromptBuilder()
            .makePrompt(context: captionContext, preference: currentGenerationPreference)
            .prompt
    }

    @MainActor
    private func saveBehaviorFeedback(
        for caption: CaptionCandidate,
        rating: Int?,
        recommendationAction: RecommendationFeedbackAction,
        dwellSeconds: Double? = nil,
        editSummary: CaptionEditSummary? = nil
    ) {
        if let rating, let index = captions.firstIndex(where: { $0.id == caption.id }) {
            captions[index].userRating = rating
        }

        if let rating {
            let event = RatingEvent(caption: caption, rating: rating)
            ratingStore.save(event)
            preferenceStore.update(from: event)
            recognitionMetricsLogger.recordCaptionRating(
                result: imageAnalysisResult,
                rating: rating,
                imageSize: selectedImage?.size
            )
        }

        let preference = currentGenerationPreference
        let recommendationEvent = feedbackCollector.makeEvent(
            caption: caption,
            action: recommendationAction,
            context: captionContext,
            targetLanguage: preference.preferredCaptionLanguage,
            isExploration: isExplorationCaption(caption),
            dwellSeconds: dwellSeconds,
            editSummary: editSummary
        )
        let updatedPreference = preferenceStore.update(fromRecommendationFeedback: recommendationEvent)
        refreshRecommendationFeedbackState()
        updateRecommendationDebugSnapshot(with: updatedPreference)
    }

    @MainActor
    private func recordManualSceneCorrectionIfNeeded() {
        guard let selectedScene = manualSceneSelection.productScene,
              let currentResult = imageAnalysisResult,
              let selectedImage else {
            return
        }

        let predictedScene = currentResult.sceneResolution.scene
        sceneCorrectionStore.record(
            predictedScene: SceneType(productScene: predictedScene),
            selectedScene: SceneType(productScene: selectedScene)
        )
        recognitionMetricsLogger.recordUserCorrection(
            result: currentResult,
            selectedScene: selectedScene,
            imageSize: selectedImage.size
        )

        let correction = ScenePrediction(
            scene: SceneType(productScene: selectedScene),
            confidence: 1,
            source: .userCorrection,
            explanation: "Current manual scene correction from developer/user."
        )
        let updatedResolution = SceneResolver().resolve(
            labels: currentResult.visionLabels,
            texts: currentResult.recognizedTexts,
            visualTraits: currentResult.visualTraits,
            customPredictions: currentResult.customSceneClassification.predictions,
            userCorrections: [correction] + sceneCorrectionStore.recentCorrectionPredictions()
        )
        let updatedSummary = ImageSemanticInterpreter.summary(
            labels: currentResult.visionLabels,
            texts: currentResult.detectedTexts,
            visualTraits: currentResult.visualTraits,
            featureFlags: currentResult.featureFlags,
            sceneResolution: updatedResolution
        )
        let updatedResult = ImageAnalysisResult(
            visionLabels: currentResult.visionLabels,
            recognizedTexts: currentResult.recognizedTexts,
            visualTraits: currentResult.visualTraits,
            featureFlags: currentResult.featureFlags,
            sceneResolution: updatedResolution,
            semanticSummary: updatedSummary,
            customSceneClassification: currentResult.customSceneClassification,
            analysisLatencyMs: currentResult.analysisLatencyMs
        )

        imageAnalysisResult = updatedResult
        imageUnderstandingResult = updatedResult.understandingResult
    }

    private func isExplorationCaption(_ caption: CaptionCandidate) -> Bool {
        lastRecommendationResult?.rankedCaptions.first { $0.candidate.id == caption.id }?.isExploration ?? false
    }

    private func updateRecommendationDebugSnapshot(with preference: UserPreference) {
        guard let lastRecommendationResult else {
            return
        }

        self.lastRecommendationResult = CaptionRecommendationResult(
            rankedCaptions: lastRecommendationResult.rankedCaptions,
            recommendedFilter: lastRecommendationResult.recommendedFilter,
            recentFeedback: recommendationFeedbackEvents,
            preferenceSnapshot: preference.recommendationProfile
        )
    }

    @MainActor
    private func queuePhotoTrainingContribution(
        sceneJson: String,
        context: CaptionGenerationContext,
        preference: UserPreference,
        source: TrainingContributionSource
    ) {
        guard pendingTrainingContributionPrompt == nil else {
            return
        }

        let prompt = makeTrainingContributionPrompt(
            kind: .photo,
            source: source,
            scope: TrainingContributionConstants.photoContributionScope,
            sceneJson: sceneJson,
            captionText: nil,
            captionWasEdited: false,
            context: context,
            preference: preference
        )
        handleTrainingContributionPrompt(prompt)
    }

    @MainActor
    private func queueCaptionTrainingContribution(
        finalCaption: CaptionCandidate,
        editSummary: CaptionEditSummary,
        context: CaptionGenerationContext,
        preference: UserPreference,
        source: TrainingContributionSource
    ) {
        guard pendingTrainingContributionPrompt == nil else {
            return
        }

        let sceneJson = CaptionGenerationPromptBuilder()
            .makePrompt(context: context, preference: preference, detail: .compact)
            .contextJSON

        let prompt = makeTrainingContributionPrompt(
            kind: .caption,
            source: source,
            scope: TrainingContributionConstants.captionContributionScope,
            sceneJson: sceneJson,
            captionText: finalCaption.text,
            captionWasEdited: editSummary.wasEdited,
            context: context,
            preference: preference
        )
        handleTrainingContributionPrompt(prompt)
    }

    @MainActor
    private func handleTrainingContributionPrompt(_ prompt: TrainingContributionPrompt) {
        switch trainingContributionStore.loadGlobalDecision() {
        case .granted:
            Task {
                await submitTrainingContribution(prompt, rememberDecision: false, showStatus: false)
            }
        case .declined:
            break
        case nil:
            pendingTrainingContributionPrompt = prompt
        }
    }

    @MainActor
    private func makeTrainingContributionPrompt(
        kind: TrainingContributionKind,
        source: TrainingContributionSource,
        scope: String,
        sceneJson: String?,
        captionText: String?,
        captionWasEdited: Bool,
        context: CaptionGenerationContext,
        preference: UserPreference
    ) -> TrainingContributionPrompt {
        let consentId = UUID()
        let sampleId = UUID()
        let now = Date()
        let titleAndMessage = localizedContributionPromptText(kind: kind)
        let scene = context.analysisResult?.sceneResolution.scene.rawValue ?? context.primaryScene.rawValue
        let confidence = context.analysisResult?.sceneResolution.confidence

        let consent = TrainingContributionConsentRequest(
            appUserId: userIdentityManager.appUserId,
            consentId: consentId,
            kind: kind,
            decision: .granted,
            scope: scope,
            privacyPolicyVersion: TrainingContributionConstants.privacyPolicyVersion,
            locale: preference.preferredCaptionLanguage.rawValue,
            createdAt: now
        )
        let sample = TrainingContributionSampleRequest(
            appUserId: userIdentityManager.appUserId,
            consentId: consentId,
            sampleId: sampleId,
            kind: kind,
            source: source,
            consentGranted: true,
            privacyPolicyVersion: TrainingContributionConstants.privacyPolicyVersion,
            locale: preference.preferredCaptionLanguage.rawValue,
            targetPlatform: selectedPlatform,
            scene: scene,
            sceneConfidence: confidence,
            sceneTags: Array(context.sceneTags.prefix(12)),
            sceneJson: sceneJson,
            captionText: captionText,
            captionWasEdited: captionWasEdited,
            imageUploadEnabled: false,
            originalPhotoRetention: TrainingContributionConstants.metadataOnlyRetention,
            createdAt: now,
            notes: "Beta metadata-only contribution. Original photo is not uploaded."
        )

        return TrainingContributionPrompt(
            title: titleAndMessage.title,
            message: titleAndMessage.message,
            confirmTitle: localizedContributionConfirmTitle,
            declineTitle: localizedContributionDeclineTitle,
            consentRequest: consent,
            sampleRequest: sample
        )
    }

    @MainActor
    private func submitTrainingContribution(
        _ prompt: TrainingContributionPrompt,
        rememberDecision: Bool = true,
        showStatus: Bool = true
    ) async {
        pendingTrainingContributionPrompt = nil
        if rememberDecision {
            trainingContributionStore.saveGlobalDecision(.granted)
        }

        do {
            _ = try await trainingContributionService.submitConsent(prompt.consentRequest)
            let response = try await trainingContributionService.submitSample(prompt.sampleRequest)

            trainingContributionStore.record(
                TrainingContributionLocalRecord(
                    id: UUID(),
                    appUserId: prompt.sampleRequest.appUserId,
                    consentId: prompt.sampleRequest.consentId,
                    sampleId: prompt.sampleRequest.sampleId,
                    kind: prompt.sampleRequest.kind,
                    source: prompt.sampleRequest.source,
                    decision: .granted,
                    scene: prompt.sampleRequest.scene,
                    targetPlatform: prompt.sampleRequest.targetPlatform,
                    storageMode: response.storageMode,
                    createdAt: Date()
                )
            )
            if showStatus {
                contributionStatusMessage = localizedContributionAcceptedText
            }
        } catch {
            if showStatus {
                contributionStatusMessage = localizedContributionFailedText
            }
        }
    }

    @MainActor
    private func declineTrainingContribution(_ prompt: TrainingContributionPrompt) {
        pendingTrainingContributionPrompt = nil
        trainingContributionStore.saveGlobalDecision(.declined)
        trainingContributionStore.record(
            TrainingContributionLocalRecord(
                id: UUID(),
                appUserId: prompt.sampleRequest.appUserId,
                consentId: prompt.sampleRequest.consentId,
                sampleId: nil,
                kind: prompt.sampleRequest.kind,
                source: prompt.sampleRequest.source,
                decision: .declined,
                scene: prompt.sampleRequest.scene,
                targetPlatform: prompt.sampleRequest.targetPlatform,
                storageMode: "local-declined",
                createdAt: Date()
            )
        )
        contributionStatusMessage = localizedContributionDeclinedText
    }

    @MainActor
    private func resetCaptionDwellTimer() {
        currentCaptionShownAt = Date()
    }

    private func currentCaptionDwellSeconds(for caption: CaptionCandidate) -> Double? {
        guard captions.indices.contains(currentCaptionIndex),
              captions[currentCaptionIndex].id == caption.id else {
            return nil
        }

        return max(0, Date().timeIntervalSince(currentCaptionShownAt))
    }

    @MainActor
    private func showTransientMessage(_ message: String) {
        let confirmationID = UUID()
        copyConfirmationID = confirmationID
        copyConfirmationMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if copyConfirmationID == confirmationID {
                copyConfirmationMessage = nil
            }
        }
    }

    @MainActor
    private func updateEnhancedImage() {
        guard let selectedImage else {
            enhancedImage = nil
            return
        }

        enhancedImage = imageEnhancementService.enhance(selectedImage, preset: selectedEnhancementPreset)
    }

    @MainActor
    private func analyzeSelectedImage(_ image: UIImage, requestID: UUID) async {
        isUnderstandingImage = true
        imageUnderstandingError = nil

        let result = await imageAnalyzer.analyze(image)

        guard imageUnderstandingRequestID == requestID else {
            return
        }

        imageAnalysisResult = result
        imageUnderstandingResult = result.understandingResult
        recognitionMetricsLogger.recordPrediction(result: result, imageSize: image.size)
        lastFoundationPrompt = CaptionGenerationPromptBuilder()
            .makePrompt(context: captionContext, preference: currentGenerationPreference)
            .prompt
        isUnderstandingImage = false

        if !result.hasUsefulContext {
            imageUnderstandingError = localizedVisionNoSceneText
        }
    }

    @MainActor
    private func resetGeneratedCaptions() {
        captions = []
        currentCaptionIndex = 0
        resetCaptionDwellTimer()
        lastGenerationMode = nil
        lastGenerationStatusMessage = nil
        lastRecommendationResult = nil
        captionGenerationError = nil
        cloudEnhancementError = nil
        cloudEnhancementStatusMessage = nil
        contributionStatusMessage = nil
    }

    private func refreshLocalAIStatus() {
        let status = captionService.localAIStatus()
        let localizedStatus = uiLanguage.localAIStatusText(status)
        localAIStatusText = localizedStatus.title
        localAIStatusDetail = localizedStatus.detail
    }

    private func localizedContributionPromptText(kind: TrainingContributionKind) -> (title: String, message: String) {
        switch (uiLanguage, kind) {
        case (.simplifiedChinese, .photo):
            return (
                "匿名贡献照片理解结果？",
                "这会帮助改进场景识别。当前版本只上传场景 JSON、标签和置信度，不上传原图，也不上传照片位置等隐私信息。"
            )
        case (.simplifiedChinese, .caption):
            return (
                "匿名贡献这条最终文案？",
                "这会帮助改进文案质量。我们只记录你最终分享或编辑后的文字和少量场景信息，不上传原图。"
            )
        case (.english, .photo):
            return (
                "Contribute photo understanding?",
                "This helps improve scene recognition. This build sends scene JSON, tags, and confidence only. The original photo is not uploaded."
            )
        case (.english, .caption):
            return (
                "Contribute this final caption?",
                "This helps improve caption quality. Only the final shared or edited text and light scene metadata are sent. The original photo is not uploaded."
            )
        case (.japanese, .photo):
            return (
                "写真理解結果を匿名で提供しますか？",
                "シーン認識の改善に役立ちます。このバージョンではシーン JSON、タグ、信頼度のみを送信し、元画像はアップロードしません。"
            )
        case (.japanese, .caption):
            return (
                "最終文案を匿名で提供しますか？",
                "文案品質の改善に役立ちます。共有または編集後の文字と軽いシーン情報のみを送信し、元画像はアップロードしません。"
            )
        case (.traditionalChinese, .photo):
            return (
                "匿名貢獻照片理解結果？",
                "這會幫助改進場景識別。目前版本只上傳場景 JSON、標籤和信心分數，不上傳原圖，也不上傳照片位置等隱私資訊。"
            )
        case (.traditionalChinese, .caption):
            return (
                "匿名貢獻這條最終文案？",
                "這會幫助改進文案品質。我們只記錄你最終分享或編輯後的文字和少量場景資訊，不上傳原圖。"
            )
        }
    }

    private var localizedContributionConfirmTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "贡献"
        case .english:
            return "Contribute"
        case .japanese:
            return "提供する"
        case .traditionalChinese:
            return "貢獻"
        }
    }

    private var localizedContributionDeclineTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "不贡献"
        case .english:
            return "Not now"
        case .japanese:
            return "提供しない"
        case .traditionalChinese:
            return "不貢獻"
        }
    }

    private var localizedContributionAcceptedText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "已记录匿名贡献授权，本次只提交 metadata，不上传原图。"
        case .english:
            return "Anonymous contribution accepted. Only metadata was sent; the original photo was not uploaded."
        case .japanese:
            return "匿名提供を記録しました。送信したのはメタデータのみで、元画像はアップロードしていません。"
        case .traditionalChinese:
            return "已記錄匿名貢獻授權，本次只提交 metadata，不上傳原圖。"
        }
    }

    private var localizedContributionDeclinedText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "已跳过匿名贡献。"
        case .english:
            return "Contribution skipped."
        case .japanese:
            return "匿名提供をスキップしました。"
        case .traditionalChinese:
            return "已略過匿名貢獻。"
        }
    }

    private var localizedContributionFailedText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "贡献提交暂时失败，不影响本次使用。"
        case .english:
            return "Contribution failed for now. This does not affect the current result."
        case .japanese:
            return "提供の送信に一時的に失敗しました。今回の利用には影響しません。"
        case .traditionalChinese:
            return "貢獻提交暫時失敗，不影響本次使用。"
        }
    }

    private var localizedCloudNeedLocalCaptionsText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "请先生成本地文案，再使用云端增强。"
        case .english:
            return "Generate local captions first, then use cloud enhancement."
        case .japanese:
            return "先にローカル文案を生成してから、クラウド強化を使ってください。"
        case .traditionalChinese:
            return "請先生成本地文案，再使用雲端增強。"
        }
    }

    private var localizedCloudQuotaExceededText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "后端返回：今天的云端增强次数已用完。"
        case .english:
            return "Backend says today's cloud enhancement quota has been used."
        case .japanese:
            return "バックエンドによると、本日のクラウド強化回数を使い切りました。"
        case .traditionalChinese:
            return "後端返回：今天的雲端增強次數已用完。"
        }
    }

    private var localizedCloudEnhanceFailedText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "云端增强暂时不可用，已保留本地文案。"
        case .english:
            return "Cloud enhancement is unavailable. Local captions are kept."
        case .japanese:
            return "クラウド強化は一時的に利用できません。ローカル文案を保持しました。"
        case .traditionalChinese:
            return "雲端增強暫時不可用，已保留本地文案。"
        }
    }

    private func localizedCloudEnhanceSuccessText(provider: String, remainingQuota: Int?) -> String {
        let remainingText = remainingQuota.map { "\($0)" }
        let modeName = provider == "mock" ? localizedCloudMockModeName : provider

        switch uiLanguage {
        case .simplifiedChinese:
            return "已使用\(modeName)增强文案。\(remainingText.map { "后端剩余额度：\($0)。" } ?? "")"
        case .english:
            return "Enhanced with \(modeName). \(remainingText.map { "Backend quota left: \($0)." } ?? "")"
        case .japanese:
            return "\(modeName)で文案を強化しました。\(remainingText.map { "バックエンド残り回数：\($0)。" } ?? "")"
        case .traditionalChinese:
            return "已使用\(modeName)增強文案。\(remainingText.map { "後端剩餘額度：\($0)。" } ?? "")"
        }
    }

    private var localizedCloudMockModeName: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "云端增强测试模式"
        case .english:
            return "cloud enhancement test mode"
        case .japanese:
            return "クラウド強化テストモード"
        case .traditionalChinese:
            return "雲端增強測試模式"
        }
    }

    private var localizedPhotoLoadFailedText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "图片加载失败，请重新选择。"
        case .english:
            return "Photo failed to load. Please choose it again."
        case .japanese:
            return "写真を読み込めませんでした。もう一度選んでください。"
        case .traditionalChinese:
            return "圖片載入失敗，請重新選擇。"
        }
    }

    private var localizedCameraUnavailableText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "当前设备没有可用相机，请在真机上测试拍照，或从相册选择照片。"
        case .english:
            return "No camera is available on this device. Test camera capture on a real iPhone or choose from the library."
        case .japanese:
            return "このデバイスではカメラを利用できません。実機で撮影を試すか、アルバムから選んでください。"
        case .traditionalChinese:
            return "目前裝置沒有可用相機，請在真機測試拍照，或從相簿選擇照片。"
        }
    }

    private var localizedSelectPhotoFirstText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "请先选择一张照片。"
        case .english:
            return "Please choose a photo first."
        case .japanese:
            return "先に写真を選んでください。"
        case .traditionalChinese:
            return "請先選擇一張照片。"
        }
    }

    private var localizedSceneStillRecognizingText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "照片场景还在识别中，请稍等一下。"
        case .english:
            return "The photo scene is still being recognized. Please wait a moment."
        case .japanese:
            return "写真シーンを認識中です。少しお待ちください。"
        case .traditionalChinese:
            return "照片場景還在識別中，請稍等一下。"
        }
    }

    private var localizedSceneSuggestChooseText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "场景置信度低于 75%，建议手动选择一个场景方向。"
        case .english:
            return "Scene confidence is below 75%. Choosing a scene manually is recommended."
        case .japanese:
            return "シーン信頼度が75%未満です。手動でシーンを選ぶことをおすすめします。"
        case .traditionalChinese:
            return "場景信心低於 75%，建議手動選擇一個場景方向。"
        }
    }

    private var localizedSceneMustChooseText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "场景置信度低于 45%，请先手动选择场景方向再生成。"
        case .english:
            return "Scene confidence is below 45%. Please choose a scene manually before generating."
        case .japanese:
            return "シーン信頼度が45%未満です。生成前に手動でシーンを選んでください。"
        case .traditionalChinese:
            return "場景信心低於 45%，請先手動選擇場景方向再生成。"
        }
    }

    private var localizedGenerationFailedText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "生成失败，请重试。"
        case .english:
            return "Generation failed. Please try again."
        case .japanese:
            return "生成に失敗しました。もう一度お試しください。"
        case .traditionalChinese:
            return "生成失敗，請重試。"
        }
    }

    private var localizedVisionNoSceneText: String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "Vision 没有识别到明确场景，可以手动选择。"
        case .english:
            return "Vision did not find a clear scene. You can choose one manually."
        case .japanese:
            return "Vision では明確なシーンを認識できませんでした。手動で選べます。"
        case .traditionalChinese:
            return "Vision 沒有識別到明確場景，可以手動選擇。"
        }
    }

    private func makeShareFileURLs(caption: String, image: UIImage) throws -> ShareFileURLs {
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapCopyShare-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let captionURL = exportDirectory.appendingPathComponent("SnapCopy文案.txt")
        let imageURL = exportDirectory.appendingPathComponent("SnapCopy图片-\(selectedEnhancementPreset.displayName).jpg")

        try caption.write(to: captionURL, atomically: true, encoding: .utf8)

        guard let imageData = image.jpegData(compressionQuality: 0.92) ?? image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }

        try imageData.write(to: imageURL, options: .atomic)

        return ShareFileURLs(captionURL: captionURL, imageURL: imageURL)
    }
}

private struct ShareFileURLs {
    let captionURL: URL
    let imageURL: URL
}

private struct CloudVisionImagePayload {
    let base64: String
    let mimeType: String
}

private struct CloudSceneEnhancementResult {
    let sceneJson: String
    let captionRequestID: UUID
}

private enum CloudEnhancementPhase: CaseIterable {
    case idle
    case preparing
    case understandingPhoto
    case writingCaptions
    case arrangingResults

    static var activeSteps: [CloudEnhancementPhase] {
        [.preparing, .understandingPhoto, .writingCaptions, .arrangingResults]
    }

    var stepIndex: Int {
        Self.activeSteps.firstIndex(of: self) ?? 0
    }

    func title(for language: AppLanguage) -> String {
        switch (language, self) {
        case (_, .idle):
            return ""
        case (.simplifiedChinese, .preparing):
            return "准备云端增强"
        case (.english, .preparing):
            return "Preparing cloud enhancement"
        case (.japanese, .preparing):
            return "クラウド強化を準備中"
        case (.traditionalChinese, .preparing):
            return "準備雲端增強"
        case (.simplifiedChinese, .understandingPhoto):
            return "正在理解照片"
        case (.english, .understandingPhoto):
            return "Understanding the photo"
        case (.japanese, .understandingPhoto):
            return "写真を理解しています"
        case (.traditionalChinese, .understandingPhoto):
            return "正在理解照片"
        case (.simplifiedChinese, .writingCaptions):
            return "正在润色文案"
        case (.english, .writingCaptions):
            return "Polishing captions"
        case (.japanese, .writingCaptions):
            return "文案を磨いています"
        case (.traditionalChinese, .writingCaptions):
            return "正在潤色文案"
        case (.simplifiedChinese, .arrangingResults):
            return "正在整理结果"
        case (.english, .arrangingResults):
            return "Arranging the results"
        case (.japanese, .arrangingResults):
            return "結果を整えています"
        case (.traditionalChinese, .arrangingResults):
            return "正在整理結果"
        }
    }

    func detail(for language: AppLanguage) -> String {
        switch (language, self) {
        case (_, .idle):
            return ""
        case (.simplifiedChinese, .preparing):
            return "把照片线索和你的偏好先整理好。"
        case (.english, .preparing):
            return "Gathering photo cues and your preferences first."
        case (.japanese, .preparing):
            return "写真の手がかりと好みを整理しています。"
        case (.traditionalChinese, .preparing):
            return "先整理照片線索和你的偏好。"
        case (.simplifiedChinese, .understandingPhoto):
            return "看清主体、光线和氛围，不急着下结论。"
        case (.english, .understandingPhoto):
            return "Reading the subject, light, and mood before writing."
        case (.japanese, .understandingPhoto):
            return "被写体、光、雰囲気を丁寧に読み取っています。"
        case (.traditionalChinese, .understandingPhoto):
            return "看清主體、光線和氛圍，不急著下結論。"
        case (.simplifiedChinese, .writingCaptions):
            return "把画面细节写进更自然的表达里。"
        case (.english, .writingCaptions):
            return "Turning the image details into natural wording."
        case (.japanese, .writingCaptions):
            return "画面の細部を自然な言葉にしています。"
        case (.traditionalChinese, .writingCaptions):
            return "把畫面細節寫進更自然的表達裡。"
        case (.simplifiedChinese, .arrangingResults):
            return "把更贴图的选项排在前面，马上就好。"
        case (.english, .arrangingResults):
            return "Putting the most fitting options first."
        case (.japanese, .arrangingResults):
            return "写真に合う候補を前に並べています。"
        case (.traditionalChinese, .arrangingResults):
            return "把更貼圖的選項排在前面，馬上就好。"
        }
    }

    static func comfortText(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return "通常需要 10–30 秒，可以先放松一下。"
        case .english:
            return "This usually takes 10-30 seconds. You can relax for a moment."
        case .japanese:
            return "通常 10〜30 秒ほどかかります。少しだけお待ちください。"
        case .traditionalChinese:
            return "通常需要 10–30 秒，可以先放鬆一下。"
        }
    }
}

private struct CloudEnhancementWaitingView: View {
    let phase: CloudEnhancementPhase
    let language: AppLanguage

    @State private var isBreathing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SnapCopyTheme.rose.opacity(0.12))

                    Image(systemName: "sparkles")
                        .font(.system(size: 21, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(SnapCopyTheme.rose)
                        .scaleEffect(isBreathing ? 1.08 : 0.94)
                        .opacity(isBreathing ? 1 : 0.72)
                }
                .frame(width: 44, height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.74), lineWidth: 1)
                }
                .shadow(color: SnapCopyTheme.rose.opacity(isBreathing ? 0.20 : 0.08), radius: isBreathing ? 14 : 6, y: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.title(for: language))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SnapCopyTheme.primaryText)

                    Text(phase.detail(for: language))
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 6) {
                ForEach(Array(CloudEnhancementPhase.activeSteps.enumerated()), id: \.element) { index, step in
                    Capsule()
                        .fill(progressColor(for: index))
                        .frame(height: 7)
                        .overlay(alignment: .leading) {
                            if step == phase {
                                Capsule()
                                    .fill(.white.opacity(0.52))
                                    .frame(width: isBreathing ? 42 : 16, height: 3)
                                    .padding(.horizontal, 3)
                            }
                        }
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBreathing)
                }
            }
            .accessibilityHidden(true)

            Text(CloudEnhancementPhase.comfortText(for: language))
                .font(.caption2.weight(.medium))
                .foregroundStyle(SnapCopyTheme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.48), in: Capsule())
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(SnapCopyTheme.glassHighlight.opacity(0.45))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.68), lineWidth: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    private func progressColor(for index: Int) -> Color {
        if index < phase.stepIndex {
            return SnapCopyTheme.rose.opacity(0.72)
        }

        if index == phase.stepIndex {
            return SnapCopyTheme.rose.opacity(0.48)
        }

        return SnapCopyTheme.hairline.opacity(0.86)
    }
}

private struct CaptionShareDraft: Identifiable {
    let id = UUID()
    let caption: CaptionCandidate
    let image: UIImage?
    let dwellSeconds: Double?
}

private enum CaptionShareMode {
    case captionCard
    case photoWithCaption
}

private struct CaptionShareEditView: View {
    @EnvironmentObject private var appLanguageManager: AppLanguageManager

    let draft: CaptionShareDraft
    let onCancel: () -> Void
    let onConfirm: (String, CaptionShareMode) -> Void

    @State private var editedText: String
    @State private var shareAsCard: Bool

    init(
        draft: CaptionShareDraft,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (String, CaptionShareMode) -> Void
    ) {
        self.draft = draft
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _editedText = State(initialValue: draft.caption.text)
        _shareAsCard = State(initialValue: draft.image != nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SnapCopyTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(uiLanguage.text(.editBeforeShareSubtitle))
                            .font(.subheadline)
                            .foregroundStyle(SnapCopyTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(uiLanguage.text(.originalCaption))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(SnapCopyTheme.secondaryText)

                            Text(draft.caption.text)
                                .font(.subheadline)
                                .foregroundStyle(SnapCopyTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(SnapCopyTheme.controlBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(uiLanguage.text(.finalCaption))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(SnapCopyTheme.primaryText)

                                Spacer()

                                Button(uiLanguage.text(.restoreOriginal)) {
                                    editedText = draft.caption.text
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(SnapCopyTheme.rose)
                            }

                            TextEditor(text: $editedText)
                                .font(.body)
                                .foregroundStyle(SnapCopyTheme.primaryText)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(minHeight: 170)
                                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(SnapCopyTheme.hairline, lineWidth: 1)
                                }
                        }

                        if draft.image != nil {
                            Toggle(isOn: $shareAsCard) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(uiLanguage.text(.shareAsCard))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(SnapCopyTheme.primaryText)

                                    Text(uiLanguage.text(.shareAsCardSubtitle))
                                        .font(.footnote)
                                        .foregroundStyle(SnapCopyTheme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .tint(SnapCopyTheme.rose)
                            .padding(16)
                            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(SnapCopyTheme.hairline, lineWidth: 1)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(uiLanguage.text(.editBeforeShareTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(uiLanguage.text(.cancel), action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(uiLanguage.text(.confirmShare)) {
                        onConfirm(editedText, shareAsCard ? .captionCard : .photoWithCaption)
                    }
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var uiLanguage: AppLanguage {
        appLanguageManager.language
    }
}

private struct SnapCopyPhotoPreview: View {
    let image: UIImage
    let accessibilityLabel: String
    var height: CGFloat = 280

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: height)
                .clipped()
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(SnapCopyTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.64), lineWidth: 1)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ImageSelectionRequest {
    let selectionID: UUID
    let understandingRequestID: UUID
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]
    let onComplete: ((Bool) -> Void)?
}

private struct SnapCopyLiquidBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    SnapCopyTheme.petal.opacity(0.16),
                    SnapCopyTheme.mintMist.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 92) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(index.isMultiple(of: 2) ? 0.26 : 0.14),
                                    SnapCopyTheme.petal.opacity(index.isMultiple(of: 2) ? 0.16 : 0.08),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 72)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -10 : 8))
                        .offset(x: index.isMultiple(of: 2) ? -40 : 52)
                }
            }
            .blur(radius: 18)
            .opacity(0.72)
        }
    }
}

private struct SnapCopyLiquidCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(SnapCopyTheme.glassHighlight.opacity(0.78))
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.86),
                                SnapCopyTheme.petal.opacity(0.30),
                                Color.white.opacity(0.36)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: SnapCopyTheme.rose.opacity(0.10), radius: 24, y: 14)
            .shadow(color: Color.white.opacity(0.72), radius: 1, y: -1)
    }
}

private extension View {
    func liquidGlassCard(cornerRadius: CGFloat = SnapCopyTheme.largeCornerRadius) -> some View {
        modifier(SnapCopyLiquidCardModifier(cornerRadius: cornerRadius))
    }

    func toolbarGlassIcon() -> some View {
        self
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(SnapCopyTheme.rose)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: SnapCopyTheme.rose.opacity(0.10), radius: 12, y: 6)
    }
}

private struct SnapCopyPhotoSourceButtonLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    var minHeight: CGFloat = 64

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.62), lineWidth: 1)
                    }

                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)

            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(SnapCopyTheme.primaryText)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .contentShape(RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
    }
}

private struct SnapCopyHoldActionButton<Label: View>: View {
    let tint: Color
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    private let holdDuration = 0.3
    @State private var isPressed = false

    var body: some View {
        label()
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPressed ? 0.28 : 0.58),
                                    tint.opacity(isPressed ? 0.18 : 0.10),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                    .stroke(.white.opacity(isPressed ? 0.36 : 0.78), lineWidth: 1)
                    .frame(height: isPressed ? 64 : 68)
            }
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                    .fill(tint.opacity(isPressed ? 0.08 : 0.18))
                    .frame(height: isPressed ? 2 : 6)
                    .blur(radius: isPressed ? 3 : 5)
                    .padding(.horizontal, 14)
                    .padding(.bottom, isPressed ? 3 : 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
            .shadow(color: tint.opacity(isPressed ? 0.08 : 0.24), radius: isPressed ? 6 : 18, y: isPressed ? 3 : 12)
            .shadow(color: Color.white.opacity(isPressed ? 0.24 : 0.72), radius: 1, y: -1)
            .scaleEffect(isPressed ? 0.955 : 1)
            .offset(y: isPressed ? 4 : 0)
            .contentShape(RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
            .onLongPressGesture(
                minimumDuration: holdDuration,
                maximumDistance: 28,
                pressing: { pressing in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
                        isPressed = pressing
                    }
                },
                perform: {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.78)) {
                        isPressed = false
                    }
                    triggerHapticFeedback()
                    action()
                }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                action()
            }
    }

    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.78)
    }
}

private struct SnapCopyPressableGlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && isEnabled

        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPressed ? 0.28 : 0.58),
                                    tint.opacity(isPressed ? 0.18 : 0.10),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                    .stroke(.white.opacity(isPressed ? 0.36 : 0.78), lineWidth: 1)
                    .frame(height: isPressed ? 64 : 68)
            }
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                    .fill(tint.opacity(isPressed ? 0.08 : 0.18))
                    .frame(height: isPressed ? 2 : 6)
                    .blur(radius: isPressed ? 3 : 5)
                    .padding(.horizontal, 14)
                    .padding(.bottom, isPressed ? 3 : 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
            .shadow(color: tint.opacity(isPressed ? 0.08 : 0.24), radius: isPressed ? 6 : 18, y: isPressed ? 3 : 12)
            .shadow(color: Color.white.opacity(isPressed ? 0.24 : 0.72), radius: 1, y: -1)
            .scaleEffect(isPressed ? 0.955 : 1)
            .offset(y: isPressed ? 4 : 0)
            .opacity(isEnabled ? 1 : 0.42)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

private struct SnapCopyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .foregroundStyle(.white)
            .background(SnapCopyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
            .shadow(color: SnapCopyTheme.rose.opacity(isEnabled ? 0.18 : 0), radius: 12, y: 6)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.42)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct SnapCopySecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .foregroundStyle(SnapCopyTheme.rose)
            .background(SnapCopyTheme.controlBackground, in: RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.62), lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.42)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
