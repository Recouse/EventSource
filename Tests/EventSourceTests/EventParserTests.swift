//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation
import Testing
@testable import EventSource

struct EventParserTests {
    @Test func eventParsing() async throws {
        var parser = ServerEventParser()
        
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
        
        let events = parser.parse(data)

        #expect(events.count == 5)

        let event0Data = try #require(events[safe: 0]?.data)
        #expect(event0Data == "test 1")

        let event1Data = try #require(events[safe: 1]?.data)
        #expect(event1Data == "test 2\ncontinued")

        let event2Event = try #require(events[safe: 2]?.event)
        let event2Data = try #require(events[safe: 2]?.data)
        #expect(event2Event == "add")
        #expect(event2Data == "test 3")

        let event3Event = try #require(events[safe: 3]?.event)
        let event3Data = try #require(events[safe: 3]?.data)
        #expect(event3Event == "remove")
        #expect(event3Data == "test 4")

        let event4ID = try #require(events[safe: 4]?.id)
        let event4Event = try #require(events[safe: 4]?.event)
        let event4Data = try #require(events[safe: 4]?.data)
        #expect(event4ID == "5")
        #expect(event4Event == "ping")
        #expect(event4Data == "test 5")
    }

    @Test func emptyData() async {
        var parser = ServerEventParser()

        let text = """
        
        
        """
        let data = Data(text.utf8)
        
        let events = parser.parse(data)

        #expect(events.isEmpty)
    }
    
    @Test func otherEventFormats() async throws {
        var parser = ServerEventParser()

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
                
        let events = parser.parse(data)

        let event0Data = try #require(events[safe: 0]?.data)
        #expect(event0Data == "test 1")

        let event1ID = try #require(events[safe: 1]?.id)
        let event1Data = try #require(events[safe: 1]?.data)
        #expect(event1ID == "2")
        #expect(event1Data == "test 2")

        let event2 = try #require(events[safe: 2]?.event)
        let event2Data = try #require(events[safe: 2]?.data)
        #expect(event2 == "add")
        #expect(event2Data == "test 3")

        let event3ID = try #require(events[safe: 3]?.id)
        let event3 = try #require(events[safe: 3]?.event)
        let event3Data = try #require(events[safe: 3]?.data)
        #expect(event3ID == "4")
        #expect(event3 == "ping")
        #expect(event3Data == "test 4")

        let event4Other = try #require(events[safe: 4]?.other?["test 5"])
        #expect(event4Other == "")

        let event5Other1 = try #require(events[safe: 5]?.other?["message 6"])
        let event5Other2 = try #require(events[safe: 5]?.other?["message 6-1"])
        #expect(event5Other1 == "")
        #expect(event5Other2 == "")
    }

    @Test func dataOnlyMode() async throws {
        var parser = ServerEventParser(mode: .dataOnly)
        let jsonDecoder = JSONDecoder()

        let text = """
        data: {"id":"abcd-1","type":"message","content":"\\ntest\\n"}

        data: {"id":"abcd-2","type":"message","content":"\\n\\n"}
        
        
        """
        let data = Data(text.utf8)

        let events = parser.parse(data)

        let data1 = Data(try #require(events[0].data?.utf8))
        let data2 = Data(try #require(events[1].data?.utf8))

        let model1 = try jsonDecoder.decode(TestModel.self, from: data1)
        let model2 = try jsonDecoder.decode(TestModel.self, from: data2)

        #expect(model1.content == "\ntest\n")
        #expect(model2.content == "\n\n")
    }

    @Test func parseNotCompleteEvent() async throws {
        var parser = ServerEventParser()

        let text = """
        data: test 1
        """
        let data = Data(text.utf8)

        let events = parser.parse(data)

        #expect(events.isEmpty)
    }

    @Test func parseSeparatedEvent() async throws {
        var parser = ServerEventParser()

        let textPart1 = """
        event: add
        
        """
        let dataPart1 = Data(textPart1.utf8)
        let textPart2 = """
        data: test 1
        
        
        """
        let dataPart2 = Data(textPart2.utf8)

        let _ = parser.parse(dataPart1)
        let events = parser.parse(dataPart2)

        #expect(events.count == 1)

        let event = try #require(events.first?.event)
        let eventData = try #require(events.first?.data)
        #expect(event == "add")
        #expect(eventData == "test 1")
    }
}

fileprivate extension EventParserTests {
    struct TestModel: Decodable {
        let id: String
        let type: String
        let content: String
    }
}
