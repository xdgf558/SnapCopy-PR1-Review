import XCTest
@testable import SnapCopy

final class LocalCaptionResponseParserTests: XCTestCase {
    func testParsesEnvelopeResponse() throws {
        let parser = LocalCaptionResponseParser()
        let captions = try parser.parse("""
        {
          "captions": [
            {
              "text": "把今天调成自己喜欢的样子。",
              "style": "healing",
              "platform": "wechat",
              "lengthLevel": "medium",
              "emojiLevel": "none",
              "scene": "daily"
            }
          ]
        }
        """)

        XCTAssertEqual(captions.count, 1)
        XCTAssertEqual(captions[0].text, "把今天调成自己喜欢的样子。")
        XCTAssertEqual(captions[0].style, .healing)
        XCTAssertEqual(captions[0].platform, .wechat)
    }

    func testParsesMarkdownWrappedResponse() throws {
        let parser = LocalCaptionResponseParser()
        let captions = try parser.parse("""
        ```json
        [
          {
            "text": "今天也有好好生活的证据。",
            "style": "daily",
            "platform": "general",
            "lengthLevel": "short",
            "emojiLevel": "light",
            "scene": "daily"
          }
        ]
        ```
        """)

        XCTAssertEqual(captions.count, 1)
        XCTAssertEqual(captions[0].emojiLevel, .light)
    }

    func testFallsBackToDefaultsForUnknownEnumValues() throws {
        let parser = LocalCaptionResponseParser()
        let captions = try parser.parse("""
        {
          "captions": [
            {
              "text": "先把这一刻留下。",
              "style": "unknown-style",
              "platform": "unknown-platform",
              "lengthLevel": "unknown-length",
              "emojiLevel": "unknown-emoji",
              "scene": "unknown-scene"
            }
          ]
        }
        """)

        XCTAssertEqual(captions[0].style, .daily)
        XCTAssertEqual(captions[0].platform, .general)
        XCTAssertEqual(captions[0].lengthLevel, .medium)
        XCTAssertEqual(captions[0].emojiLevel, .none)
        XCTAssertEqual(captions[0].scene, .daily)
    }

    func testSanitizesMetadataLeakedIntoCaptionText() throws {
        let parser = LocalCaptionResponseParser()
        let captions = try parser.parse("""
        {
          "captions": [
            {
              "text": "在这低光下，这只小猫正专注地享受它的晚餐。\\npremium\\ninstagram\\nmedium\\nnone\\npet",
              "style": "premium",
              "platform": "instagram",
              "lengthLevel": "medium",
              "emojiLevel": "none",
              "scene": "pet"
            }
          ]
        }
        """)

        XCTAssertEqual(captions.count, 1)
        XCTAssertEqual(captions[0].text, "在这低光下，这只小猫正专注地享受它的晚餐。")
    }

    func testDropsCaptionWhenTextOnlyContainsMetadata() throws {
        let parser = LocalCaptionResponseParser()
        let captions = try parser.parse("""
        {
          "captions": [
            {
              "text": "premium\\ninstagram\\nmedium\\nnone\\npet",
              "style": "premium",
              "platform": "instagram",
              "lengthLevel": "medium",
              "emojiLevel": "none",
              "scene": "pet"
            }
          ]
        }
        """)

        XCTAssertTrue(captions.isEmpty)
    }

    func testSanitizerDropsProviderJSONFragments() {
        let sanitizer = CaptionTextSanitizer()

        XCTAssertNil(sanitizer.sanitizedText(from: "{"))
        XCTAssertNil(sanitizer.sanitizedText(from: #""captions": ["#))
        XCTAssertNil(sanitizer.sanitizedText(from: "premium\ninstagram\nmedium\nnone\npet"))
        XCTAssertEqual(
            sanitizer.sanitizedText(from: "窗边的猫把今天晒得很松弛。\npremium\ninstagram\nmedium\nnone\npet"),
            "窗边的猫把今天晒得很松弛。"
        )
    }
}
