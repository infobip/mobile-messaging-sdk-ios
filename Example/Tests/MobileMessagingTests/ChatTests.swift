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

	func testUpdateWithChatWidget_NilTitle_AppliesWidgetTitle() {
		let settings = MMChatSettings()
		settings.title = nil

		let attachments = ChatWidgetAttachmentSettings(maxSize: 10000, isEnabled: true, allowedExtensions: ["pdf"])
		let widget = ChatWidget(
			id: "test",
			title: "Support Chat",
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
			themeNames: [],
			attachments: attachments
		)

		settings.update(withChatWidget: widget)

		XCTAssertEqual(settings.title, "Support Chat")
	}

	func testUpdateWithChatWidget_ExistingTitle_PreservesTitle() {
		let settings = MMChatSettings()
		settings.title = "My Custom Title"

		let attachments = ChatWidgetAttachmentSettings(maxSize: 10000, isEnabled: true, allowedExtensions: ["pdf"])
		let widget = ChatWidget(
			id: "test",
			title: "Support Chat",
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
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

		let attachments = ChatWidgetAttachmentSettings(maxSize: 10000, isEnabled: true, allowedExtensions: ["pdf"])
		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: "#FF5733",
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
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

		let attachments = ChatWidgetAttachmentSettings(maxSize: 10000, isEnabled: true, allowedExtensions: ["pdf"])
		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: "#FF5733",
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
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

		let attachments = ChatWidgetAttachmentSettings(maxSize: 10000, isEnabled: true, allowedExtensions: ["pdf"])
		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: "#FFFFFF",
			multiThread: false,
			callsEnabled: false,
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

		let attachments = ChatWidgetAttachmentSettings(maxSize: 10000, isEnabled: true, allowedExtensions: ["pdf"])
		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: nil,
			primaryTextColor: nil,
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
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

		let attachments = ChatWidgetAttachmentSettings(maxSize: 10000, isEnabled: true, allowedExtensions: ["pdf"])
		let widget = ChatWidget(
			id: "test",
			title: nil,
			primaryColor: nil,
			primaryTextColor: "#333333",
			backgroundColor: nil,
			multiThread: false,
			callsEnabled: false,
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
		// Should contain UUID or some generated filename
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
