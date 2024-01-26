//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import XCTest
@testable import EventSource

final class MessageParserTests: XCTestCase {
    func testMessagesParsing() throws {
        let parser = MessageParser.live
        
        let text = """
        data: test 1

        data: test 2
        data: continued

        event: add
        data: test 3

        event: remove
        data: test 4

        id: 5
        event: ping
        data: test 5
        """
        let data = Data(text.utf8)
        
        let messages = parser.parse(data)
        
        XCTAssertEqual(messages.count, 5)
        
        XCTAssertNotNil(messages[0].data)
        XCTAssertEqual(messages[0].data!, "test 1")
        
        XCTAssertNotNil(messages[1].data)
        XCTAssertEqual(messages[1].data!, "test 2\ncontinued")
        
        XCTAssertNotNil(messages[2].event)
        XCTAssertNotNil(messages[2].data)
        XCTAssertEqual(messages[2].event!, "add")
        XCTAssertEqual(messages[2].data!, "test 3")
        
        XCTAssertNotNil(messages[3].event)
        XCTAssertNotNil(messages[3].data)
        XCTAssertEqual(messages[3].event!, "remove")
        XCTAssertEqual(messages[3].data!, "test 4")
        
        XCTAssertNotNil(messages[4].id)
        XCTAssertNotNil(messages[4].event)
        XCTAssertNotNil(messages[4].data)
        XCTAssertEqual(messages[4].id!, "5")
        XCTAssertEqual(messages[4].event!, "ping")
        XCTAssertEqual(messages[4].data!, "test 5")
    }
    
    func testEmptyData() {
        let parser = MessageParser.live
        
        let text = """
        
        
        """
        let data = Data(text.utf8)
        
        let messages = parser.parse(data)
        
        XCTAssertTrue(messages.isEmpty)
    }
    
    func testOtherMessageFormats() {
        let parser = MessageParser.live
        
        let text = """
        data : test 1

        id : 2
         data : test 2

         event : add
        data :  test 3

        id : 4
        event : ping
        data : test 4
        """
        let data = Data(text.utf8)
                
        let messages = parser.parse(data)
        
        XCTAssertNotNil(messages[0].data)
        XCTAssertEqual(messages[0].data!, "test 1")
        
        XCTAssertNotNil(messages[1].id)
        XCTAssertNotNil(messages[1].data)
        XCTAssertEqual(messages[1].id!, "2")
        XCTAssertEqual(messages[1].data!, "test 2")
        
        XCTAssertNotNil(messages[2].event)
        XCTAssertNotNil(messages[2].data)
        XCTAssertEqual(messages[2].event!, "add")
        XCTAssertEqual(messages[2].data!, "test 3")
        
        XCTAssertNotNil(messages[3].id)
        XCTAssertNotNil(messages[3].event)
        XCTAssertNotNil(messages[3].data)
        XCTAssertEqual(messages[3].id!, "4")
        XCTAssertEqual(messages[3].event!, "ping")
        XCTAssertEqual(messages[3].data!, "test 4")
    }
}
