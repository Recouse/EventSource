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
        
        :
        
        """
        let data = Data(text.utf8)
                
        let events = parser.parse(data)

        // Due to extra spaces in the field names, the first four events failed to be interpreted correctly;
        // therefore, only two events should be parsed
        #expect(events.count == 2)

        let event1Other = try #require(events[safe: 0]?.other?["test 5"])
        #expect(event1Other == "")

        let event2Other1 = try #require(events[safe: 1]?.other?["message 6"])
        let event2Other2 = try #require(events[safe: 1]?.other?["message 6-1"])
        #expect(event2Other1 == "")
        #expect(event2Other2 == "")
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

    @Test func parseWithDifferentLineEndings() async throws {
        var parser = ServerEventParser()

        // Test with CR+LF (\r\n) as line endings - using separate events for clarity
        let textCRLF = "data: test crlfline1\r\n\r\n" +
                      "data: crlfline2\r\n\r\n" +
                      "event: add\r\ndata: crlftest\r\n\r\n" + 
                      "id: 3\r\nevent: ping\r\ndata: crlfping\r\n\r\n"

        // Test with mixed LF (\n) and CR+LF (\r\n) - using separate events
        let textMixed = "data: test mixedline1\n\n" +
                       "data: mixedline2\r\n\n" +
                       "event: update\r\ndata: mixedtest\n\n" +
                       "id: 4\nevent: pong\r\ndata: mixedpong\r\n\n"
        
        // Convert to Data
        let dataCRLF = Data(textCRLF.utf8)
        let dataMixed = Data(textMixed.utf8)

        // Parse pure CR+LF format
        let eventsCRLF = parser.parse(dataCRLF)
        #expect(eventsCRLF.count == 4)
        #expect(eventsCRLF.compactMap(\.id) == ["3"])
        #expect(eventsCRLF.compactMap(\.data) == ["test crlfline1", "crlfline2", "crlftest", "crlfping"])
        #expect(eventsCRLF.compactMap(\.event) == ["add", "ping"])

        let eventsMixed = parser.parse(dataMixed)
        #expect(eventsMixed.count == 4)
        #expect(eventsMixed.compactMap(\.id) == ["4"])
        #expect(eventsMixed.compactMap(\.data) == ["test mixedline1", "mixedline2", "mixedtest", "mixedpong"])
        #expect(eventsMixed.compactMap(\.event) == ["update", "pong"])
    }
}

fileprivate extension EventParserTests {
    struct TestModel: Decodable {
        let id: String
        let type: String
        let content: String
    }
}
