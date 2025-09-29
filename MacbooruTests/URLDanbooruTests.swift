import XCTest

@testable import Macbooru

final class URLDanbooruTests: XCTestCase {
    func testMakeDanbooruURL_absolute() {
        let u = URL.makeDanbooruURL("https://example.com/a.jpg")
        XCTAssertEqual(u?.absoluteString, "https://example.com/a.jpg")
    }

    func testMakeDanbooruURL_relative() {
        let u = URL.makeDanbooruURL("/data/preview.jpg")
        XCTAssertEqual(u?.host, "danbooru.donmai.us")
        XCTAssertTrue(u?.path.hasSuffix("/data/preview.jpg") == true)
    }

    func testMakeDanbooruURL_nilOrEmpty() {
        XCTAssertNil(URL.makeDanbooruURL(nil))
        XCTAssertNil(URL.makeDanbooruURL(""))
    }
}
