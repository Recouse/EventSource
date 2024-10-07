//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation
import Testing
@testable import EventSource

struct EventParserTests {
    @Test func messagesParsing() throws {
        let parser = EventParser.live
        
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
        
        #expect(messages.count == 5)
        
        #expect(messages[0].data != nil)
        #expect(messages[0].data! == "test 1")
        
        #expect(messages[1].data != nil)
        #expect(messages[1].data! == "test 2\ncontinued")
        
        #expect(messages[2].event != nil)
        #expect(messages[2].data != nil)
        #expect(messages[2].event! == "add")
        #expect(messages[2].data! == "test 3")
        
        #expect(messages[3].event != nil)
        #expect(messages[3].data != nil)
        #expect(messages[3].event! == "remove")
        #expect(messages[3].data! == "test 4")
        
        #expect(messages[4].id != nil)
        #expect(messages[4].event != nil)
        #expect(messages[4].data != nil)
        #expect(messages[4].id! == "5")
        #expect(messages[4].event! == "ping")
        #expect(messages[4].data! == "test 5")
    }
    
    @Test func emptyData() {
        let parser = EventParser.live
        
        let text = """
        
        
        """
        let data = Data(text.utf8)
        
        let messages = parser.parse(data)
        
        #expect(messages.isEmpty)
    }
    
    @Test func otherMessageFormats() {
        let parser = EventParser.live
        
        let text = """
        data : test 1

        id : 2
         data : test 2

         event : add
        data :  test 3

        id : 4
        event : ping
        data : test 4
        
        test 5
        
        message 6
        message 6-1
        """
        let data = Data(text.utf8)
                
        let messages = parser.parse(data)
        
        #expect(messages[0].data != nil)
        #expect(messages[0].data! == "test 1")
        
        #expect(messages[1].id != nil)
        #expect(messages[1].data != nil)
        #expect(messages[1].id! == "2")
        #expect(messages[1].data! == "test 2")
        
        #expect(messages[2].event != nil)
        #expect(messages[2].data != nil)
        #expect(messages[2].event! == "add")
        #expect(messages[2].data! == "test 3")
        
        #expect(messages[3].id != nil)
        #expect(messages[3].event != nil)
        #expect(messages[3].data != nil)
        #expect(messages[3].id! == "4")
        #expect(messages[3].event! == "ping")
        #expect(messages[3].data! == "test 4")
        
        #expect(messages[4].other != nil)
        #expect(messages[4].other!["test 5"] == "")
        
        #expect(messages[5].other != nil)
        #expect(messages[5].other!["message 6"] == "")
        #expect(messages[5].other!["message 6-1"] == "")
    }
    
    @Test func jsonData() {
        let parser = EventParser.live
        let jsonDecoder = JSONDecoder()
        
        let text = """
        data: {\"id\":\"abcd-1\",\"type\":\"message\",\"content\":\"\\ntest\\n\"}

        id: abcd-2
        data: {\"id\":\"abcd-2\",\"type\":\"message\",\"content\":\"\\n\\n"}
        
        """
        let data = Data(text.utf8)
        
        let messages = parser.parse(data)
        
        #expect(messages[0].data != nil)
        #expect(messages[1].data != nil)
        
        do {
            let _ = try jsonDecoder.decode(TestModel.self, from: Data(messages[0].data!.utf8))
            let _ = try jsonDecoder.decode(TestModel.self, from: Data(messages[1].data!.utf8))
        } catch {
            Issue.record("The JSON strings provided in the test data were parsed incorrectly.")
        }
    }
}

fileprivate extension EventParserTests {
    struct TestModel: Decodable {
        let id: String
        let type: String
        let content: String
    }
}
