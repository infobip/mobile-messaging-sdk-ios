//
//  Example/Tests/MobileMessagingTests/ChatTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessaging

// MARK: - Settings Tests

class ChatSettingsTests: MMTestCase {
    let attachments = ChatWidgetAttachmentSettings(maxSize: 10000, isEnabled: true, allowedExtensions: ["pdf"])

	func testUpdateWithChatWidget_NilTitle_AppliesWidgetTitle() {
		let settings = MMChatSettings()
		settings.title = nil

		let widget = ChatWidget(
			id: "test",
			title: "Support Chat",
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
            useNewDesign: false,
			themeNames: [],
			attachments: attachments
		)

		settings.update(withChatWidget: widget)

		XCTAssertEqual(settings.title, "Support Chat")
	}

	func testUpdateWithChatWidget_ExistingTitle_PreservesTitle() {
		let settings = MMChatSettings()
		settings.title = "My Custom Title"


		let widget = ChatWidget(
			id: "test",
			title: "Support Chat",
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
            useNewDesign: false,
			themeNames: [],
			attachments: attachments
		)

		settings.update(withChatWidget: widget)

		XCTAssertEqual(settings.title, "My Custom Title")
	}

	func testUpdateWithChatWidget_PrimaryColorNilSettings_AppliesWidgetColor() {
		let settings = MMChatSettings()
		settings.sendButtonTintColor = nil
		settings.navBarColor = nil

		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: "#FF5733",
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
            useNewDesign: false,
			themeNames: [],
			attachments: attachments
		)

		settings.update(withChatWidget: widget)

		let expectedColor = UIColor(hexString: "#FF5733")
		XCTAssertEqual(settings.sendButtonTintColor, expectedColor)
		XCTAssertEqual(settings.navBarColor, expectedColor)
	}

	func testUpdateWithChatWidget_ExistingSendButtonColor_PreservesColor() {
		let settings = MMChatSettings()
		settings.sendButtonTintColor = UIColor.blue
		settings.navBarColor = nil

		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: "#FF5733",
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
            useNewDesign: false,
			themeNames: [],
			attachments: attachments
		)

		settings.update(withChatWidget: widget)

		XCTAssertEqual(settings.sendButtonTintColor, UIColor.blue)
		XCTAssertEqual(settings.navBarColor, UIColor(hexString: "#FF5733"))
	}

	func testUpdateWithChatWidget_BackgroundColorNilSettings_AppliesWidgetBackgroundColor() {
		let settings = MMChatSettings()
		settings.backgroundColor = nil

		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: "#FFFFFF",
			multiThread: false,
			callsEnabled: false,
            useNewDesign: false,
			themeNames: [],
			attachments: attachments
		)

		settings.update(withChatWidget: widget)

		XCTAssertEqual(settings.backgroundColor, UIColor(hexString: "#FFFFFF"))
	}

	func testUpdateWithChatWidget_AllNilWidgetProperties_NoChanges() {
		let settings = MMChatSettings()
		settings.title = "Existing Title"
		settings.navBarColor = UIColor.red

		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
            callsEnabled: false,
            useNewDesign: false,
			themeNames: [],
			attachments: attachments
		)

		settings.update(withChatWidget: widget)

		XCTAssertEqual(settings.title, "Existing Title")
		XCTAssertEqual(settings.navBarColor, UIColor.red)
	}

	func testUpdateWithChatWidget_PrimaryTextColor_AppliesNavBarTitleColor() {
		let settings = MMChatSettings()
		settings.navBarTitleColor = nil

		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: nil,
			primaryTextColor: "#333333",
			backgroundColor: nil,
			multiThread: false,
            callsEnabled: false,
            useNewDesign: false,
			themeNames: [],
			attachments: attachments
		)

		settings.update(withChatWidget: widget)

		XCTAssertEqual(settings.navBarTitleColor, UIColor(hexString: "#333333"))
	}
}

// MARK: - Attachment Utils Tests

class ChatAttachmentUtilsTests: MMTestCase {

	func testIsCameraNeeded_OnlyVideoExtensions_ReturnsTrue() {
		let allowedTypes = ["mp4", "mov", "avi"]

		let result = ChatAttachmentUtils.isCameraNeeded(for: allowedTypes)

		XCTAssertTrue(result)
	}

	func testIsCameraNeeded_OnlyImageExtensions_ReturnsTrue() {
		let allowedTypes = ["jpg", "png", "gif", "heic"]

		let result = ChatAttachmentUtils.isCameraNeeded(for: allowedTypes)

		XCTAssertTrue(result)
	}

	func testIsCameraNeeded_BothVideoAndImageExtensions_ReturnsTrue() {
		let allowedTypes = ["mp4", "jpg", "png"]

		let result = ChatAttachmentUtils.isCameraNeeded(for: allowedTypes)

		XCTAssertTrue(result)
	}

	func testIsCameraNeeded_OnlyDocumentExtensions_ReturnsFalse() {
		let allowedTypes = ["pdf", "docx", "txt", "xlsx"]

		let result = ChatAttachmentUtils.isCameraNeeded(for: allowedTypes)

		XCTAssertFalse(result)
	}

	func testIsCameraNeeded_EmptyAllowedTypes_ReturnsFalse() {
		let allowedTypes: [String] = []

		let result = ChatAttachmentUtils.isCameraNeeded(for: allowedTypes)

		XCTAssertFalse(result)
	}

	func testIsCameraNeeded_MixedVideoAndDocuments_ReturnsTrue() {
		let allowedTypes = ["mp4", "pdf", "docx"]

		let result = ChatAttachmentUtils.isCameraNeeded(for: allowedTypes)

		XCTAssertTrue(result)
	}

	func testConvertToUTType_ValidExtensions_ReturnsUTTypeArray() {
		let extensions = ["pdf", "png", "txt"]

		let result = ChatAttachmentUtils.convertToUTType(extensions)

		XCTAssertEqual(result.count, 3)
		XCTAssertTrue(result.contains(where: { $0.identifier.contains("pdf") }))
	}

	func testConvertToUTType_EmptyInput_ReturnsEmptyArray() {
		let extensions: [String] = []

		let result = ChatAttachmentUtils.convertToUTType(extensions)

		XCTAssertEqual(result.count, 0)
	}

	func testConvertToUTType_InvalidExtension_FiltersOut() {
		let extensions = ["pdf", "invalidextension123", "png"]

		let result = ChatAttachmentUtils.convertToUTType(extensions)

		// Should have at least 2 valid UTTypes (pdf and png)
		XCTAssertGreaterThanOrEqual(result.count, 2)
	}
}

// MARK: - Error Tests

class ChatErrorTests: MMTestCase {

	func testChatLocalError_MessageLengthExceeded_FormatsCorrectly() {
		let error = MMChatLocalError.messageLengthExceeded(10000)

		let userInfo = error.userInfo

		XCTAssertTrue(userInfo[NSLocalizedDescriptionKey]?.contains("10000") ?? false)
		XCTAssertTrue(userInfo[NSLocalizedDescriptionKey]?.contains("Message length exceeded") ?? false)
	}

	func testChatLocalError_AttachmentSizeExceeded_FormatsCorrectly() {
		let error = MMChatLocalError.attachmentSizeExceeded(5000000)

		let userInfo = error.userInfo

		XCTAssertTrue(userInfo[NSLocalizedDescriptionKey]?.contains("5000000") ?? false)
		XCTAssertTrue(userInfo[NSLocalizedDescriptionKey]?.contains("Attachment size exceeded") ?? false)
	}

	func testChatLocalError_WrongPayload_FormatsCorrectly() {
		let error = MMChatLocalError.wrongPayload

		let userInfo = error.userInfo

		XCTAssertTrue(userInfo[NSLocalizedDescriptionKey]?.contains("Incorrect payload values") ?? false)
	}

	func testChatLocalError_AttachmentNotAllowed_FormatsCorrectly() {
		let error = MMChatLocalError.attachmentNotAllowed

		let userInfo = error.userInfo

		XCTAssertTrue(userInfo[NSLocalizedDescriptionKey]?.contains("Attachment uploading or file extension not allowed") ?? false)
	}

	func testChatLocalError_NoPushRegistrationId_FormatsCorrectly() {
		let error = MMChatLocalError.noPushRegistrationId

		let userInfo = error.userInfo

		XCTAssertTrue(userInfo[NSLocalizedDescriptionKey]?.contains("No push registration Id") ?? false)
	}

	func testChatLocalError_NoWidget_FormatsCorrectly() {
		let error = MMChatLocalError.noWidget

		let userInfo = error.userInfo

		XCTAssertTrue(userInfo[NSLocalizedDescriptionKey]?.contains("No widget") ?? false)
	}

	func testChatLocalError_APIRequestFailure_FormatsWithAllParameters() {
		let error = MMChatLocalError.apiRequestFailure(.send, "Network timeout", "{\"data\":\"test\"}")

		let userInfo = error.userInfo

		let description = userInfo[NSLocalizedDescriptionKey] ?? ""
		XCTAssertTrue(description.contains("send"))
		XCTAssertTrue(description.contains("Network timeout"))
		XCTAssertTrue(description.contains("{\"data\":\"test\"}"))
		XCTAssertNotNil(userInfo["reason"])
		XCTAssertNotNil(userInfo["payload"])
	}

	func testChatLocalError_APIRequestFailure_FormatsWithNilParameters() {
		let error = MMChatLocalError.apiRequestFailure(.getThreads, nil, nil)

		let userInfo = error.userInfo

		let description = userInfo[NSLocalizedDescriptionKey] ?? ""
		XCTAssertTrue(description.contains("getThreads"))
		XCTAssertNil(userInfo["reason"])
		XCTAssertNil(userInfo["payload"])
	}

	func testChatLocalError_WrongPayload_TechnicalMessageContainsDocumentationLink() {
		let error = MMChatLocalError.wrongPayload

		let technicalMessage = error.technicalMessage

		XCTAssertTrue(technicalMessage.contains("https://github.com/infobip/mobile-messaging-sdk-ios/wiki"))
	}

	func testChatLocalError_NoPushRegistrationId_TechnicalMessageContainsSetupInstructions() {
		let error = MMChatLocalError.noPushRegistrationId

		let technicalMessage = error.technicalMessage

		XCTAssertTrue(technicalMessage.contains("push registration Id"))
		XCTAssertTrue(technicalMessage.contains("https://"))
	}

	func testChatLocalError_NoWidget_TechnicalMessageContainsConfigurationGuidance() {
		let error = MMChatLocalError.noWidget

		let technicalMessage = error.technicalMessage

		XCTAssertTrue(technicalMessage.contains("widget"))
		XCTAssertTrue(technicalMessage.contains("https://"))
	}
}

// MARK: - Payload Serialization Tests

class ChatPayloadTests: MMTestCase {

	func testBasicPayload_TextOnly_GeneratesCorrectJavaScript() {
		let payload = MMLivechatBasicPayload(text: "Hello world", threadId: nil)

		let jsString = payload.interfaceValue

		XCTAssertTrue(jsString.contains("'message':"))
		XCTAssertTrue(jsString.contains("'type':'BASIC'"))
		XCTAssertFalse(jsString.contains("'attachment':"))
	}

	func testBasicPayload_TextWithThreadId_IncludesThreadIdInOutput() {
		let payload = MMLivechatBasicPayload(text: "Hello", threadId: "thread-123")

		let jsString = payload.interfaceValue

		XCTAssertTrue(jsString.contains("'thread-123'"))
	}

	func testBasicPayload_AttachmentOnly_GeneratesCorrectJavaScript() {
		let data = "test data".data(using: .utf8)!
		let payload = MMLivechatBasicPayload(text: nil, fileName: "test.pdf", data: data, threadId: nil)

		let jsString = payload.interfaceValue

		XCTAssertTrue(jsString.contains("'attachment':"))
		XCTAssertTrue(jsString.contains("'fileName':"))
		XCTAssertTrue(jsString.contains("test.pdf"))
		XCTAssertFalse(jsString.contains("'message':"))
	}

	func testBasicPayload_AttachmentWithoutFileName_GeneratesFilename() {
		let data = "test data".data(using: .utf8)!
		let payload = MMLivechatBasicPayload(text: nil, fileName: nil, data: data, threadId: nil)

		let jsString = payload.interfaceValue

		XCTAssertTrue(jsString.contains("'fileName':"))
		// Should contain date as string or some generated filename
		XCTAssertFalse(jsString.contains("'fileName': 'null'"))
	}

	func testFormattedThreadId_NilThreadId_ReturnsEmptyString() {
		let payload = MMLivechatBasicPayload(text: "test", threadId: nil)

		let formatted = payload.formattedThreadId

		XCTAssertEqual(formatted, "")
	}

	func testFormattedThreadId_EmptyThreadId_ReturnsEmptyString() {
		let payload = MMLivechatBasicPayload(text: "test", threadId: "")

		let formatted = payload.formattedThreadId

		XCTAssertEqual(formatted, "")
	}

	func testFormattedThreadId_ValidThreadId_ReturnsFormattedString() {
		let payload = MMLivechatBasicPayload(text: "test", threadId: "thread-456")

		let formatted = payload.formattedThreadId

		XCTAssertEqual(formatted, ", 'thread-456'")
	}

	func testDraftPayload_GeneratesCorrectJavaScript() {
		let payload = MMLivechatDraftPayload(text: "Draft message", threadId: "thread-789")

		let jsString = payload.interfaceValue

		XCTAssertTrue(jsString.contains("'message':"))
		XCTAssertTrue(jsString.contains("'type':'DRAFT'"))
		XCTAssertTrue(jsString.contains("'thread-789'"))
	}

	func testCustomPayload_WithAllFields_GeneratesCorrectJavaScript() {
		let payload = MMLivechatCustomPayload(
			customData: "{\"key\":\"value\"}",
			agentMessage: "Agent says hi",
			userMessage: "User replies",
			threadId: "thread-abc"
		)

		let jsString = payload.interfaceValue

		XCTAssertTrue(jsString.contains("'customData':"))
		XCTAssertTrue(jsString.contains("'agentMessage':"))
		XCTAssertTrue(jsString.contains("'userMessage':"))
		XCTAssertTrue(jsString.contains("'type':'CUSTOM_DATA'"))
		XCTAssertTrue(jsString.contains("'thread-abc'"))
	}

	func testCustomPayload_WithNilAgentMessage_IncludesNullAgentMessage() {
		let payload = MMLivechatCustomPayload(
			customData: "{}",
			agentMessage: nil,
			userMessage: "User message",
			threadId: nil
		)

		let jsString = payload.interfaceValue

		// agentMessage is always included, but as null when nil
		XCTAssertTrue(jsString.contains("'agentMessage':null"))
		XCTAssertTrue(jsString.contains("'userMessage':"))
	}
}

// MARK: - Language and Locale Tests

class ChatLanguageTests: MMTestCase {

	func testSetLanguage_EnglishUSWithUnderscore_SetsEnglish() {
		MMTestCase.startWithCorrectApplicationCode()
		_ = mobileMessagingInstance.withInAppChat()

        guard let service = MMInAppChatService.sharedInstance else { XCTFail("Should have thrown error"); return }
		service.setLanguage("en_US")

		let language = MMLanguage.sessionLanguage
		XCTAssertEqual(language, MMLanguage.en)
	}

	func testSetLanguage_EnglishUSWithDash_SetsEnglish() {
		MMTestCase.startWithCorrectApplicationCode()
		_ = mobileMessagingInstance.withInAppChat()

        guard let service = MMInAppChatService.sharedInstance else { XCTFail("Should have thrown error"); return }
		service.setLanguage("en-US")

		let language = MMLanguage.sessionLanguage
		XCTAssertEqual(language, MMLanguage.en)
	}

	func testSetLanguage_SpanishLocale_SetsSpanish() {
		MMTestCase.startWithCorrectApplicationCode()
		_ = mobileMessagingInstance.withInAppChat()

        guard let service = MMInAppChatService.sharedInstance else { XCTFail("Should have thrown error"); return }
		service.setLanguage("es_ES")

		let language = MMLanguage.sessionLanguage
		XCTAssertEqual(language, MMLanguage.es)
	}

	func testSetLanguage_OnlyLanguageCode_ParsesCorrectly() {
		MMTestCase.startWithCorrectApplicationCode()
		_ = mobileMessagingInstance.withInAppChat()

        guard let service = MMInAppChatService.sharedInstance else { XCTFail("Should have thrown error"); return }
		service.setLanguage("fr")

		let language = MMLanguage.sessionLanguage
		// Should map to French
		XCTAssertEqual(language, MMLanguage.fr)
	}
}

// MARK: - Thread Status Tests

class ChatThreadTests: MMTestCase {

	func testThreadStatus_OpenString_ReturnsOpenStatus() {
		let status = MMLiveChatThread.Status(rawValue: "OPEN")

		XCTAssertEqual(status, .open)
	}

	func testThreadStatus_SolvedString_ReturnsSolvedStatus() {
		let status = MMLiveChatThread.Status(rawValue: "SOLVED")

		XCTAssertEqual(status, .solved)
	}

	func testThreadStatus_ClosedString_ReturnsClosedStatus() {
		let status = MMLiveChatThread.Status(rawValue: "CLOSED")

		XCTAssertEqual(status, .closed)
	}

	func testThreadStatus_UnknownString_ReturnsUnknownStatus() {
		let status = MMLiveChatThread.Status(rawValue: "UNKNOWN")

		XCTAssertEqual(status, .unknown)
	}

	func testThreadStatus_InvalidString_ReturnsNil() {
		let status = MMLiveChatThread.Status(rawValue: "INVALIDSTATUS")

		XCTAssertNil(status)
	}
}

// MARK: - Chat Widget Tests

class ChatWidgetTests: MMTestCase {

	func testChatWidget_AttachmentsSettings_StoresCorrectly() {
		let attachmentSettings = ChatWidgetAttachmentSettings(
			maxSize: 3000000,
			isEnabled: true,
			allowedExtensions: ["pdf", "jpg", "png"]
		)

		XCTAssertTrue(attachmentSettings.isEnabled)
		XCTAssertEqual(attachmentSettings.maxSize, 3000000)
		XCTAssertEqual(attachmentSettings.allowedExtensions.count, 3)
		XCTAssertTrue(attachmentSettings.allowedExtensions.contains("pdf"))
	}
}

// MARK: - Chat notification routing tests

final class ChatNotificationRoutingTests: MMTestCase {
    private final class UnresponsivePresenter: UIViewController {
        var onPresent: (() -> Void)?
        var pendingCompletion: (() -> Void)?

        override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
            pendingCompletion = completion
            onPresent?()
        }
    }

    private final class PresenterDelegate: MMMessageHandlingDelegate {
        let presenter: UIViewController

        init(presenter: UIViewController) {
            self.presenter = presenter
        }

        func inAppPresentingViewController(for message: MM_MTMessage) -> UIViewController? {
            presenter
        }
    }

    private final class ErrorLogger: MMLogging {
        var logOutput: MMLogOutput = .Console
        var logLevel: MMLogLevel = .All
        var logFilePaths: [String]? = nil
        var onError: ((String) -> Void)?

        func sendLogs(fromViewController vc: UIViewController) {}
        func logDebug(message: String) {}
        func logInfo(message: String) {}
        func logError(message: String) { onError?(message) }
        func logWarn(message: String) {}
        func logVerbose(message: String) {}
    }

    private final class PresentationDelegate: MMMessageHandlingDelegate {
        var onBroadcastChat: ((MM_MTMessage) -> Void)?
        var onInboundChat: ((MM_MTMessage) -> Void)?

        func inAppOpenLiveChatActionTapped(for message: MM_MTMessage) {
            onBroadcastChat?(message)
        }

        func inAppInboundLiveChatPushTapped(for message: MM_MTMessage) {
            onInboundChat?(message)
        }
    }

    private final class OpenNewThreadRecordingAPI: MMInAppChatWidgetAPI {
        var onOpenNewThread: (() -> Void)?

        override func loadWidget() {}

        override func openNewThread(completion: @escaping (Error?) -> Void) {
            onOpenNewThread?()
            completion(nil)
        }
    }

    private final class LoadedChat: ChatWebViewDelegate, MMLiveChatThreadsActions, MMChatBasicWebViewActions, MMChatInternalWebViewActions {
        var onOpenThread: ((String) -> Void)?
        var onCreateThread: (() -> Void)?
        var onOpenNewThread: (() -> Void)?

        func didLoad(_ widget: ChatWidget) {}
        func didReceive(_ errors: MMChatRemoteError) {}
        func didDetectWrongSetup(_ localError: MMChatLocalError) {}
        func didEnableControls(_ enabled: Bool) {}
        func didShowComposeBar(_ visible: Bool) {}
        func didOpenPreview(forAttachment attachment: ChatWebAttachment) {}
        func didChangeView(_ state: MMChatWebViewState) {}
        @MainActor func sendContextualData(_ contextualData: ContextualData) async throws {}

        func send(_ payload: MMLivechatPayload, completion: @escaping (Error?) -> Void) {
            completion(nil)
        }

        func send(_ payload: MMLivechatPayload) async throws {}

        func createThread(_ payload: MMLivechatPayload, completion: @escaping (MMLiveChatThread?, Error?) -> Void) {
            onCreateThread?()
            completion(MMLiveChatThread(id: "created-thread", conversationId: nil, status: .open), nil)
        }

        func createThread(_ payload: MMLivechatPayload) async throws -> MMLiveChatThread {
            onCreateThread?()
            return MMLiveChatThread(id: "created-thread", conversationId: nil, status: .open)
        }

        func openNewThread(completion: @escaping (Error?) -> Void) {
            onOpenNewThread?()
            completion(nil)
        }

        func openThread(with id: String) async throws -> MMLiveChatThread {
            onOpenThread?(id)
            return MMLiveChatThread(id: id, conversationId: nil, status: .open)
        }

        func openThread(with id: String, completion: @escaping (Result<MMLiveChatThread, Error>) -> Void) {
            XCTFail("Notification routing should use the async thread action")
        }

        func getThreads(completion: @escaping (Result<[MMLiveChatThread], Error>) -> Void) {
            XCTFail("Unexpected getThreads call")
        }

        func getThreads() async throws -> [MMLiveChatThread] {
            XCTFail("Unexpected getThreads call")
            return []
        }

        func getActiveThread(completion: @escaping (Result<MMLiveChatThread?, Error>) -> Void) {
            XCTFail("Unexpected getActiveThread call")
        }

        func getActiveThread() async throws -> MMLiveChatThread? {
            XCTFail("Unexpected getActiveThread call")
            return nil
        }

        func showThreadsList(completion: @escaping (Error?) -> Void) {
            XCTFail("Unexpected showThreadsList call")
        }

        func showThreadsList() async throws {
            XCTFail("Unexpected showThreadsList call")
        }
    }

    override func tearDown() async throws {
        await MainActor.run { MMInAppChatService.pushPresentationMode = nil }
        try await super.tearDown()
    }

    override func tearDown() {
        MobileMessaging.messageHandlingDelegate = nil
        super.tearDown()
    }

    private func makeService(
        multiThread: Bool = true,
        pushPresentationMode: MobileMessaging.InAppChatPushPresentationMode? = nil
    ) async -> MMInAppChatService {
        let mobileMessaging = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
        let service = MMInAppChatService(mmContext: mobileMessaging)
        MMInAppChatService.sharedInstance = service
        await MainActor.run { MMInAppChatService.pushPresentationMode = pushPresentationMode }
        service.chatWidget = ChatWidget(
            id: "notification-test-widget",
            title: nil,
            primaryColor: nil,
            primaryTextColor: nil,
            backgroundColor: nil,
            multiThread: multiThread,
            callsEnabled: false,
            useNewDesign: false,
            themeNames: [],
            attachments: ChatWidgetAttachmentSettings(maxSize: 0, isEnabled: false, allowedExtensions: [])
        )
        return service
    }

    private func makeMessage(
        isChatMessage: Bool = true,
        threadId: String? = "thread-123",
        openChat: Bool = false,
        keyword: String? = nil
    ) -> MM_MTMessage {
        var payload = apnsNormalMessagePayload(UUID().uuidString)
        var internalData = payload[Consts.APNSPayloadKeys.internalData] as! [String: Any]
        if openChat {
            var openChatData: [String: Any] = [:]
            if let keyword { openChatData[Consts.InternalDataKeys.liveChatKeyword] = keyword }
            internalData[Consts.InternalDataKeys.openLiveChat] = openChatData
        } else if isChatMessage {
            internalData[Consts.InternalDataKeys.messageType] = Consts.APIValues.MessageTypeValues.chat
        }
        payload[Consts.APNSPayloadKeys.internalData] = internalData
        payload[Consts.APNSPayloadKeys.customPayload] = threadId.map { [Consts.InternalDataKeys.liveChatThreadId: $0] } ?? [:]
        return MM_MTMessage(
            payload: payload,
            deliveryMethod: .push,
            seenDate: nil,
            deliveryReportDate: nil,
            seenStatus: .NotSeen,
            isDeliveryReportSent: false
        )!
    }

    @MainActor
    func testPushPresentationModeSurvivesServiceRecreationAndCanBeCleared() async {
        let service = await makeService(pushPresentationMode: .uikit)
        _ = service.mmContext.withInAppChat()
        let recreatedService = MMInAppChatService(mmContext: service.mmContext)
        MMInAppChatService.sharedInstance = recreatedService
        XCTAssertNotNil(MMInAppChatService.pushPresentationMode)

        _ = service.mmContext.withInAppChat(pushPresentationMode: nil)
        XCTAssertNil(MMInAppChatService.pushPresentationMode)
    }

    func testPushPresentationModeCanBeConfiguredSynchronouslyOffMainThread() async {
        _ = await makeService()
        let configured = expectation(description: "Background configuration completes")
        DispatchQueue.global().async {
            _ = MobileMessaging.sharedInstance?.withInAppChat(pushPresentationMode: .uikit).withInAppChat()
            configured.fulfill()
        }

        await fulfillment(of: [configured], timeout: 2)
        let mode = await MainActor.run { MMInAppChatService.pushPresentationMode }
        XCTAssertNotNil(mode)
    }

    private func assertChatTapReachesDelegate(action: MMNotificationAction, threadId: String? = "thread-123") async {
        let service = await makeService()
        let message = makeMessage(threadId: threadId)
        message.appliedAction = action
        let delegate = PresentationDelegate()
        let presented = expectation(description: "App receives tapped chat message")
        let completed = expectation(description: "Chat handling completes")
        delegate.onInboundChat = { receivedMessage in
            XCTAssertEqual(receivedMessage.messageId, message.messageId)
            XCTAssertEqual(receivedMessage.chatThreadId, threadId)
            presented.fulfill()
        }
        MobileMessaging.messageHandlingDelegate = delegate

        service.handleAnyMessage(message) { _ in completed.fulfill() }

        await fulfillment(of: [presented, completed], timeout: 2)
    }

    func testDefaultChatNotificationTapPassesThreadToPresentationDelegate() async {
        await assertChatTapReachesDelegate(action: .defaultAction)
    }

    func testPrimaryChatNotificationTapPassesThreadToPresentationDelegate() async {
        await assertChatTapReachesDelegate(action: .primaryAction)
    }

    func testChatNotificationWithoutThreadIdStillReachesPresentationDelegate() async {
        await assertChatTapReachesDelegate(action: .defaultAction, threadId: nil)
    }

    func testInboundTapWithoutWidgetUsesInboundDelegate() async {
        let service = await makeService()
        service.chatWidget = nil
        let message = makeMessage()
        message.appliedAction = .defaultAction
        let delegate = PresentationDelegate()
        let inboundTap = expectation(description: "App receives inbound tap when widget is unavailable")
        let unexpectedBroadcastTap = expectation(description: "Inbound tap must not use broadcast callback")
        unexpectedBroadcastTap.isInverted = true
        delegate.onInboundChat = { receivedMessage in
            XCTAssertEqual(receivedMessage.messageId, message.messageId)
            inboundTap.fulfill()
        }
        delegate.onBroadcastChat = { _ in unexpectedBroadcastTap.fulfill() }
        MobileMessaging.messageHandlingDelegate = delegate

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [inboundTap], timeout: 0.5)
        await fulfillment(of: [unexpectedBroadcastTap], timeout: 0.2)
    }

    func testBroadcastTapWithoutWidgetUsesBroadcastDelegate() async {
        let service = await makeService()
        service.chatWidget = nil
        let message = makeMessage(isChatMessage: false, threadId: nil, openChat: true)
        message.appliedAction = .defaultAction
        let delegate = PresentationDelegate()
        let broadcastTap = expectation(description: "App receives broadcast tap when widget is unavailable")
        delegate.onBroadcastChat = { receivedMessage in
            XCTAssertEqual(receivedMessage.messageId, message.messageId)
            broadcastTap.fulfill()
        }
        MobileMessaging.messageHandlingDelegate = delegate

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [broadcastTap], timeout: 0.5)
    }

    func testInboundChatTapWithoutOptInDoesNotPresentChat() async {
        let service = await makeService()
        let presenter = await MainActor.run { UnresponsivePresenter() }
        MobileMessaging.messageHandlingDelegate = PresenterDelegate(presenter: presenter)
        let unexpectedPresentation = expectation(description: "Inbound tap must not present chat without opt-in")
        unexpectedPresentation.isInverted = true
        let completed = expectation(description: "Chat handling completes")
        await MainActor.run { presenter.onPresent = { unexpectedPresentation.fulfill() } }
        let message = makeMessage()
        message.appliedAction = .defaultAction

        service.handleAnyMessage(message) { _ in completed.fulfill() }

        await fulfillment(of: [completed, unexpectedPresentation], timeout: 0.2)
    }

    func testNonChatNotificationTapDoesNotOpenChat() async {
        let service = await makeService()
        let message = makeMessage(isChatMessage: false)
        message.appliedAction = .defaultAction
        let delegate = PresentationDelegate()
        let unexpectedPresentation = expectation(description: "Non-chat message must not open chat")
        unexpectedPresentation.isInverted = true
        let completed = expectation(description: "Notification handling completes")
        delegate.onBroadcastChat = { _ in unexpectedPresentation.fulfill() }
        delegate.onInboundChat = { _ in unexpectedPresentation.fulfill() }
        MobileMessaging.messageHandlingDelegate = delegate

        service.handleAnyMessage(message) { _ in completed.fulfill() }

        await fulfillment(of: [completed, unexpectedPresentation], timeout: 0.2)
    }

    func testTappedChatNotificationOpensItsThreadInLoadedChat() async {
        let service = await makeService(pushPresentationMode: .uikit)
        let loadedChat = LoadedChat()
        let opened = expectation(description: "Tapped thread opens in loaded chat")
        loadedChat.onOpenThread = { threadId in
            XCTAssertEqual(threadId, "thread-123")
            opened.fulfill()
        }
        service.webViewDelegate = loadedChat
        let message = makeMessage()
        message.appliedAction = .defaultAction

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [opened], timeout: 2)
        withExtendedLifetime(loadedChat) {}
    }

    func testOpenChatKeywordUsesLoadedChatActions() async {
        let service = await makeService()
        let loadedChat = LoadedChat()
        let created = expectation(description: "Keyword creates a thread in the loaded chat")
        loadedChat.onCreateThread = { created.fulfill() }
        service.webViewDelegate = loadedChat
        let message = makeMessage(threadId: nil, openChat: true, keyword: "support")
        message.appliedAction = .defaultAction

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [created], timeout: 2)
        withExtendedLifetime(loadedChat) {}
    }

    func testDelegatedBroadcastKeywordStillCreatesThread() async {
        let service = await makeService()
        let widget = service.chatWidget
        service.chatWidget = nil
        let loadedChat = LoadedChat()
        let created = expectation(description: "Broadcast keyword creates a thread")
        loadedChat.onCreateThread = { created.fulfill() }
        service.webViewDelegate = loadedChat
        let delegate = PresentationDelegate()
        let routed = expectation(description: "Broadcast tap reaches app without waiting for widget")
        delegate.onBroadcastChat = { _ in routed.fulfill() }
        MobileMessaging.messageHandlingDelegate = delegate
        let message = makeMessage(isChatMessage: false, threadId: nil, openChat: true, keyword: "support")
        message.appliedAction = .defaultAction

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [routed], timeout: 0.5)
        service.chatWidget = widget
        await fulfillment(of: [created], timeout: 2)
        withExtendedLifetime((loadedChat, delegate)) {}
    }

    func testOpenChatWithoutKeywordOpensSingleThreadInLoadedChat() async {
        let service = await makeService()
        let loadedChat = LoadedChat()
        let opened = expectation(description: "Keywordless open-chat action opens the single thread view")
        await MainActor.run { loadedChat.onOpenNewThread = { opened.fulfill() } }
        service.webViewDelegate = loadedChat
        let message = makeMessage(threadId: nil, openChat: true)
        message.appliedAction = .defaultAction

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [opened], timeout: 2)
        withExtendedLifetime(loadedChat) {}
    }

    func testOpenChatWithoutKeywordDoesNotOpenNewThreadOnSingleThreadWidget() async {
        let service = await makeService(multiThread: false)
        let loadedChat = LoadedChat()
        let unexpectedOpen = expectation(description: "Single-thread widget must not open a new thread")
        unexpectedOpen.isInverted = true
        await MainActor.run { loadedChat.onOpenNewThread = { unexpectedOpen.fulfill() } }
        service.webViewDelegate = loadedChat
        let message = makeMessage(threadId: nil, openChat: true)
        message.appliedAction = .defaultAction

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [unexpectedOpen], timeout: 0.2)
        withExtendedLifetime(loadedChat) {}
    }

    func testOpenChatWithoutKeywordLeavesActionToPresentationDelegate() async {
        let service = await makeService()
        let api = OpenNewThreadRecordingAPI()
        service.api = api
        let unexpectedSDKAction = expectation(description: "Delegate-owned action must not use SDK chat API")
        unexpectedSDKAction.isInverted = true
        await MainActor.run { api.onOpenNewThread = { unexpectedSDKAction.fulfill() } }
        let message = makeMessage(threadId: nil, openChat: true)
        message.appliedAction = .defaultAction
        let delegate = PresentationDelegate()
        let routed = expectation(description: "Keywordless open-chat routing finished")
        delegate.onBroadcastChat = { routedMessage in
            if routedMessage.messageId == message.messageId { routed.fulfill() }
        }
        MobileMessaging.messageHandlingDelegate = delegate

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [routed], timeout: 2)
        await fulfillment(of: [unexpectedSDKAction], timeout: 0.2)
        withExtendedLifetime((delegate, api)) {}
    }

    func testNonChatNotificationDoesNotOpenThreadInLoadedChat() async {
        let service = await makeService()
        let loadedChat = LoadedChat()
        let unexpectedOpen = expectation(description: "Non-chat notification must not open a thread")
        unexpectedOpen.isInverted = true
        loadedChat.onOpenThread = { _ in unexpectedOpen.fulfill() }
        service.webViewDelegate = loadedChat
        let message = makeMessage(isChatMessage: false)
        message.appliedAction = .defaultAction

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [unexpectedOpen], timeout: 0.2)
        withExtendedLifetime(loadedChat) {}
    }

    func testRejectedChatPresentationTimesOutAndFinishesRouting() async {
        let service = await makeService(pushPresentationMode: .uikit)
        let presenter = await MainActor.run { UnresponsivePresenter() }
        let delegate = PresenterDelegate(presenter: presenter)
        MobileMessaging.messageHandlingDelegate = delegate
        let logger = ErrorLogger()
        let previousLogger = MobileMessaging.logger
        defer { MobileMessaging.logger = previousLogger }
        let presentationAttempted = expectation(description: "Chat presentation attempted")
        let presentationTimedOut = expectation(description: "Rejected presentation timed out")
        let routingFinished = expectation(description: "Thread routing continued after timeout")
        logger.onError = { message in
            if message.contains("timed out waiting for chat presentation") {
                presentationTimedOut.fulfill()
            } else if message.contains("Unable to open thread thread-123") {
                routingFinished.fulfill()
            }
        }
        MobileMessaging.logger = logger
        await MainActor.run { presenter.onPresent = { presentationAttempted.fulfill() } }
        let message = makeMessage()
        message.appliedAction = .defaultAction

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [presentationAttempted, presentationTimedOut, routingFinished], timeout: 7)
        await MainActor.run { presenter.pendingCompletion?() }
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    func testRejectedBroadcastPresentationDoesNotStartHiddenUIAction() async {
        let service = await makeService()
        let api = OpenNewThreadRecordingAPI()
        service.api = api
        let unexpectedAPIAction = expectation(description: "UI-only action must not run in the API web view")
        unexpectedAPIAction.isInverted = true
        await MainActor.run { api.onOpenNewThread = { unexpectedAPIAction.fulfill() } }
        let presenter = await MainActor.run { UnresponsivePresenter() }
        MobileMessaging.messageHandlingDelegate = PresenterDelegate(presenter: presenter)
        let logger = ErrorLogger()
        let previousLogger = MobileMessaging.logger
        defer { MobileMessaging.logger = previousLogger }
        let presentationTimedOut = expectation(description: "Rejected broadcast presentation timed out")
        logger.onError = { message in
            if message.contains("timed out waiting for chat presentation") {
                presentationTimedOut.fulfill()
            }
        }
        MobileMessaging.logger = logger
        let message = makeMessage(isChatMessage: false, threadId: nil, openChat: true)
        message.appliedAction = .defaultAction

        service.handleAnyMessage(message) { _ in }

        await fulfillment(of: [presentationTimedOut], timeout: 7)
        await fulfillment(of: [unexpectedAPIAction], timeout: 0.2)
        await MainActor.run { presenter.pendingCompletion?() }
    }
}

// MARK: - ChatWidgetLoadCoordinator Tests

class ChatWidgetLoadCoordinatorTests: XCTestCase {

	override func setUp() async throws {
		try await super.setUp()
		await ChatWidgetLoadCoordinator.shared.resetForTesting()
	}

	// MARK: Single Slot Acquire/Release

	func testAcquireAndRelease_SlotIsAvailableAfterRelease() async {
		let slot = await ChatWidgetLoadCoordinator.shared.acquireLoadingSlot()

		let isLoadingAfterAcquire = await ChatWidgetLoadCoordinator.shared.isLoading
		XCTAssertTrue(isLoadingAfterAcquire)

		slot.release()
		try? await Task.sleep(nanoseconds: 50_000_000)

		let isLoadingAfterRelease = await ChatWidgetLoadCoordinator.shared.isLoading
		XCTAssertFalse(isLoadingAfterRelease)
	}

	// MARK: Concurrency — Second Handler Waits

	func testSecondAcquire_WaitsUntilFirstReleases() async {
		let firstAcquired = expectation(description: "First slot acquired")
		let secondAcquired = expectation(description: "Second slot acquired")
		let firstReleased = expectation(description: "First slot released")

		// Acquire the first slot
		let firstSlot = await ChatWidgetLoadCoordinator.shared.acquireLoadingSlot()
		firstAcquired.fulfill()

		// Second acquirer runs concurrently — must block until first releases
		let secondTask = Task {
			let secondSlot = await ChatWidgetLoadCoordinator.shared.acquireLoadingSlot()
			secondAcquired.fulfill()
			secondSlot.release()
		}

		// Give the second Task a moment to suspend on the coordinator
		try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

		let isStillLoading = await ChatWidgetLoadCoordinator.shared.isLoading
		XCTAssertTrue(isStillLoading, "Slot should still be held before release")

		let waiterCount = await ChatWidgetLoadCoordinator.shared.waitingCount
		XCTAssertEqual(waiterCount, 1, "One continuation should be waiting")

		// Release the first slot — this should unblock the second
		firstSlot.release()
		firstReleased.fulfill()

		await fulfillment(of: [firstAcquired, firstReleased, secondAcquired], timeout: 2.0)
		_ = await secondTask.result
	}

	// MARK: Multiple Waiters

	func testMultipleWaiters_AllUnblockedEventually() async {
		let allAcquired = expectation(description: "All three acquired")
		allAcquired.expectedFulfillmentCount = 3

		let firstSlot = await ChatWidgetLoadCoordinator.shared.acquireLoadingSlot()

		var tasks: [Task<Void, Never>] = []
		for _ in 0..<3 {
			tasks.append(Task {
				let slot = await ChatWidgetLoadCoordinator.shared.acquireLoadingSlot()
				allAcquired.fulfill()
				slot.release()
			})
		}

		// Let all three tasks suspend on the coordinator
		try? await Task.sleep(nanoseconds: 50_000_000)

		let waiterCount = await ChatWidgetLoadCoordinator.shared.waitingCount
		XCTAssertEqual(waiterCount, 3)

		// Release the original holder — each subsequent release unblocks the next waiter
		firstSlot.release()

		await fulfillment(of: [allAcquired], timeout: 3.0)
		for t in tasks { _ = await t.result }
	}

	// MARK: Idempotent Release

	func testDoubleRelease_IsIdempotent() async {
		let slot = await ChatWidgetLoadCoordinator.shared.acquireLoadingSlot()
		slot.release()
		slot.release() // second call must be a no-op (ChatWidgetLoadSlot guards with released flag)

		try? await Task.sleep(nanoseconds: 50_000_000)

		let isLoading = await ChatWidgetLoadCoordinator.shared.isLoading
		XCTAssertFalse(isLoading)
	}

	// MARK: ChatWidgetLoadSlot RAII

	func testSlotDeinit_ReleasesCoordinator() async {
		var slot: ChatWidgetLoadSlot? = await ChatWidgetLoadCoordinator.shared.acquireLoadingSlot()
		XCTAssertNotNil(slot)

		let isLoadingBeforeDeinit = await ChatWidgetLoadCoordinator.shared.isLoading
		XCTAssertTrue(isLoadingBeforeDeinit)

		// Nil the slot — its deinit calls release() which fires an async Task
		// that calls releaseLoadingSlot() on the coordinator.
		slot = nil

		// Give deinit's internal Task a moment to reach the actor
		try? await Task.sleep(nanoseconds: 50_000_000)

		let isLoading = await ChatWidgetLoadCoordinator.shared.isLoading
		XCTAssertFalse(isLoading, "Slot deinit should have released the coordinator loading slot")
	}

	// MARK: ChatWidgetLoadSlot Explicit Release

	func testSlotExplicitRelease_DoubleCallIsIdempotent() async {
		let slot = await ChatWidgetLoadCoordinator.shared.acquireLoadingSlot()

		slot.release()
		slot.release() // second call must be a no-op

		// Give the async Task inside release() time to run
		try? await Task.sleep(nanoseconds: 50_000_000)

		let isLoading = await ChatWidgetLoadCoordinator.shared.isLoading
		XCTAssertFalse(isLoading)
	}
}

// MARK: - ChatViewController Compose Bar Visibility Tests

class ChatViewControllerComposeBarVisibilityTests: MMTestCase {
	private func multiThreadWidget(id: String) -> ChatWidget {
		return ChatWidget(
			id: id,
			title: nil,
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: true,
			callsEnabled: false,
			useNewDesign: false,
			themeNames: [],
			attachments: ChatWidgetAttachmentSettings(maxSize: 0, isEnabled: false, allowedExtensions: [])
		)
	}

	private func singleThreadWidget(id: String) -> ChatWidget {
		return ChatWidget(
			id: id,
			title: nil,
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
			useNewDesign: false,
			themeNames: [],
			attachments: ChatWidgetAttachmentSettings(maxSize: 0, isEnabled: false, allowedExtensions: [])
		)
	}

	// Regression test for the race: didLoad's completion used to overwrite isComposeBarVisible
	// with a stale guess (`!widget.multiThread`) even after didChangeView had already reported the
	// live view state, hiding the composer when it should stay visible.
	func testDidLoad_CompletionFlushedAfterDidChangeViewEstablishedThreadState_DoesNotStompComposeBarVisible() async {
		let vc = MMChatViewController()
		_ = vc.view

		vc.didLoad(multiThreadWidget(id: "test-widget-1"))
		vc.didChangeView(.thread)

		try? await Task.sleep(nanoseconds: 100_000_000) // let triggerPendingActions's async flush run

		XCTAssertTrue(vc.isComposeBarVisible, "Compose bar should remain visible: didLoad's completion must not stomp the live state set by didChangeView")
	}

	func testDidLoad_CompletionFlushedWhileStateStillUnknown_HidesComposeBarForMultiThreadWidget() async {
		let vc = MMChatViewController()
		_ = vc.view

		vc.didLoad(multiThreadWidget(id: "test-widget-2"))

		try? await Task.sleep(nanoseconds: 100_000_000)

		XCTAssertFalse(vc.isComposeBarVisible)
	}

	func testDidChangeView_SingleThreadWidget_ComposeBarAlwaysVisible() {
		let vc = MMChatViewController()
		_ = vc.view
		vc.didLoad(singleThreadWidget(id: "single"))

		vc.didChangeView(.loading)

		XCTAssertTrue(vc.isComposeBarVisible)
		XCTAssertFalse(vc.isChattingInMultithread)
	}

	func testDidChangeView_MultiThreadWidget_ComposeBarVisibleOnlyInThreadStates() {
		let vc = MMChatViewController()
		_ = vc.view
		vc.didLoad(multiThreadWidget(id: "multi"))

		vc.didChangeView(.threadList)
		XCTAssertFalse(vc.isComposeBarVisible)

		vc.didChangeView(.thread)
		XCTAssertTrue(vc.isComposeBarVisible)
		XCTAssertTrue(vc.isChattingInMultithread)

		vc.didChangeView(.singleThreadMode)
		XCTAssertTrue(vc.isComposeBarVisible)

		vc.didChangeView(.closedThread)
		XCTAssertFalse(vc.isComposeBarVisible)
		XCTAssertTrue(vc.isChattingInMultithread)
	}
}

// MARK: - URL.chatFilename Tests

class URLChatFilenameTests: MMTestCase {
	func testChatFilename_SingleExtension_ReturnsTimestampedNameWithSameExtension() {
		let url = URL(fileURLWithPath: "IMG_0001.MOV")
		let result = url.chatFilename
		XCTAssertNotNil(result)
		XCTAssertNotEqual(result, url.lastPathComponent)
		XCTAssertTrue(result!.hasSuffix(".MOV"))
	}

	func testChatFilename_MultiDotExtension_UsesLastComponentAsExtension() {
		let url = URL(fileURLWithPath: "archive.tar.gz")
		let result = url.chatFilename
		XCTAssertNotNil(result)
		XCTAssertTrue(result!.hasSuffix(".gz"))
	}

	func testChatFilename_NoExtension_ReturnsOriginalNameUnchanged() {
		let url = URL(fileURLWithPath: "README")
		XCTAssertEqual(url.chatFilename, "README")
	}
}

// MARK: - ChatAttachmentPicker Origin Detection Tests

private class MockChatAttachmentPickerDelegate: ChatAttachmentPickerDelegate {
	var receivedFilename: String?
	var receivedData: Data?

	func didSelect(filename: String?, data: Data) {
		receivedFilename = filename
		receivedData = data
	}
	func permissionNotGranted(permissionKeys: [String]?) {}
	func validateAttachmentSize(size: Int) -> Bool { return true }
	func attachmentSizeExceeded() {}
}

private class FakeCameraImagePickerController: UIImagePickerController {
	override var sourceType: UIImagePickerController.SourceType {
		get { .camera }
		set { /* no-op: avoids "Source type not available" crash on simulator */ }
	}
}

class ChatAttachmentPickerOriginTests: MMTestCase {
	private func makeTempFile(named name: String) -> URL {
		let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
		try? "dummy".data(using: .utf8)?.write(to: url)
		return url
	}

	func testImagePicker_FromCamera_RenamesFilenameToTimestamp() {
		let delegate = MockChatAttachmentPickerDelegate()
		let sut = ChatAttachmentPicker(delegate: delegate, allowedContentTypes: [])
		let fileURL = makeTempFile(named: "MyClip.mov")
		let picker = FakeCameraImagePickerController()

		sut.imagePickerController(picker, didFinishPickingMediaWithInfo: [.mediaURL: fileURL])

		XCTAssertNotNil(delegate.receivedFilename)
		XCTAssertNotEqual(delegate.receivedFilename, "MyClip.mov")
		XCTAssertTrue(delegate.receivedFilename?.hasSuffix(".mov") ?? false)
	}

	func testImagePicker_FromPhotoLibrary_KeepsOriginalFilename() {
		let delegate = MockChatAttachmentPickerDelegate()
		let sut = ChatAttachmentPicker(delegate: delegate, allowedContentTypes: [])
		let fileURL = makeTempFile(named: "MyClip.mov")
		let picker = UIImagePickerController()
		picker.sourceType = .photoLibrary

		sut.imagePickerController(picker, didFinishPickingMediaWithInfo: [.mediaURL: fileURL])

		XCTAssertEqual(delegate.receivedFilename, "MyClip.mov")
	}

	func testDocumentPicker_KeepsOriginalFilename() {
		let delegate = MockChatAttachmentPickerDelegate()
		let sut = ChatAttachmentPicker(delegate: delegate, allowedContentTypes: [])
		let fileURL = makeTempFile(named: "Report.pdf")
		let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [])

		sut.documentPicker(documentPicker, didPickDocumentAt: fileURL)

		XCTAssertEqual(delegate.receivedFilename, "Report.pdf")
	}
}
