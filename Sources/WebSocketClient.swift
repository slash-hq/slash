//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

class WebSocketClient {
    
    enum Err: Error {
        
        case unknownOpCode(String)
        case unMaskedFrame
        case notImplemented(String)
        case invalidFrameLength(String)
        case io(String)
    }
    
    enum OpCode: UInt8 {
        
        case `continue` = 0x00
        case close = 0x08
        case ping = 0x09
        case pong = 0x0A
        case text = 0x01
        case binary = 0x02
    }
    
    struct Frame {
        
        let opcode: OpCode
        let payload: [UInt8]
    }
    
    private let mask: [UInt8]
    private let socket: TLSSocket
    
    private var inputBuffer = [UInt8]()
    
    init(_ host: String, path: String) throws {
        
        self.mask = WebSocketClient.provideRandomValues(4)
        
        self.socket = try TLSSocket(try WebSocketClient.addressForHost(host))
        
        let secWebSocketKey = Data(WebSocketClient.provideRandomValues(16)).base64EncodedString()
        
        let handshakeRequest = [UInt8]((
            "GET \(path)?encoding=text HTTP/1.1\r\n" +
            "Host: \(host)\r\n" +
            "Pragma:no-cache\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Cache-Control: no-cache\r\n" +
            "Sec-WebSocket-Version: 13\r\n" +
            "Sec-WebSocket-Key: \(secWebSocketKey)\r\n\r\n").utf8)
        
        try self.socket.writeData(handshakeRequest)
        
        //TODO: parse http response in a better way to validate returned Sec-WebSocket-Accept.
        
        skipHeaders: while true {
            let chunk = try self.socket.readData()
            var iteratpr = chunk.makeIterator()
            while let b = iteratpr.next() {
                if b != 13 { inputBuffer.append(b) }
                if inputBuffer.count >= 2 && inputBuffer.last == 10 && inputBuffer[inputBuffer.endIndex - 2] == 10 {
                    inputBuffer.removeAll(keepingCapacity: true)
                    inputBuffer.append(contentsOf: iteratpr)
                    break skipHeaders
                }
            }
        }
    }
    
    func writeFrame(fin: Bool = true, opcode: OpCode, payload: [UInt8] = []) throws  {
        var data = [UInt8]()
        data.append(UInt8(fin ? 0x80 : 0x00) | opcode.rawValue)
        data.append(contentsOf: encodeLengthAndMaskFlag(UInt64(payload.count), mask: self.mask))
        data.append(contentsOf: payload.enumerated().map { item in
            item.element ^ self.mask[item.offset % self.mask.count]
        })
        try self.socket.writeData(data)
    }
    
    private class func provideRandomValues(_ count: Int) -> [UInt8] {
        var result = [UInt8]()
        for _ in 0..<count {
            result.append(UInt8(arc4random() % UInt32(UInt8.max)))
        }
        return result
    }

    private func encodeLengthAndMaskFlag(_ len: UInt64, mask: [UInt8]? = nil) -> [UInt8] {
        let encodedLngth = UInt8(mask != nil ? 0x80 : 0x00)
        var encodedBytes = [UInt8]()
        switch len {
        case 0...125:
            encodedBytes.append(encodedLngth | UInt8(len));
        case 126...UInt64(UINT16_MAX):
            encodedBytes.append(encodedLngth | 0x7E);
            encodedBytes.append(UInt8(len >> 8 & 0xFF));
            encodedBytes.append(UInt8(len >> 0 & 0xFF));
        default:
            encodedBytes.append(encodedLngth | 0x7F);
            encodedBytes.append(UInt8(len >> 56 & 0xFF));
            encodedBytes.append(UInt8(len >> 48 & 0xFF));
            encodedBytes.append(UInt8(len >> 40 & 0xFF));
            encodedBytes.append(UInt8(len >> 32 & 0xFF));
            encodedBytes.append(UInt8(len >> 24 & 0xFF));
            encodedBytes.append(UInt8(len >> 16 & 0xFF));
            encodedBytes.append(UInt8(len >> 08 & 0xFF));
            encodedBytes.append(UInt8(len >> 00 & 0xFF));
        }
        if let mask = mask {
            encodedBytes.append(contentsOf: mask)
        }
        return encodedBytes
    }
    
    func waitForFrame() throws -> Frame? {
    
        // Handle remaining frames after the handshake.
        
        if let frame = try self.lookfForFrame() {
            return frame
        }
        
        inputBuffer.append(contentsOf: try self.socket.readData())
        
        if let frame = try self.lookfForFrame() {
            return frame
        }
        
        return nil
    }
    
    private func lookfForFrame() throws -> Frame? {
        
        guard inputBuffer.count > 1 else { return nil }
        
        let _ /* fin flag */ = inputBuffer[0] & 0x80 != 0
        let opc = inputBuffer[0] & 0x0F
        
        guard let opcode = OpCode(rawValue: opc) else {
            // "If an unknown opcode is received, the receiving endpoint MUST _Fail the WebSocket Connection_."
            // http://tools.ietf.org/html/rfc6455#section-5.2 ( Page 29 )
            throw Err.unknownOpCode("\(opc)")
        }
        
        var offset = 2
        var len = UInt64(0)
        
        switch UInt64(inputBuffer[1] & 0x7F) {
        case let short where short < 0x7E:
            len = short
        case 0x7E:
            guard inputBuffer.count > 3 else { return nil }
            len = UInt64(littleEndian: UInt64(inputBuffer[2]) << 8 | UInt64(inputBuffer[3]))
            offset = 4
        case 0x7F:
            guard inputBuffer.count > 9 else { return nil }
            let byte2 = UInt64(inputBuffer[2]) << 54
            let byte3 = UInt64(inputBuffer[3]) << 48
            let byte4 = UInt64(inputBuffer[4]) << 40
            let byte5 = UInt64(inputBuffer[5]) << 32
            let byte6 = UInt64(inputBuffer[6]) << 24
            let byte7 = UInt64(inputBuffer[7]) << 16
            let byte8 = UInt64(inputBuffer[8]) << 8
            let byte9 = UInt64(inputBuffer[9])
            len = UInt64(littleEndian: byte2 | byte3 | byte4 | byte5 | byte6 | byte7 | byte8 | byte9)
            offset = 10
        default:
            throw Err.invalidFrameLength("Not allowed frame length: \(len)")
        }
        
        let masked = (inputBuffer[1] & 0x80) != 0
        
        guard (len + UInt64(offset) + (masked ? 4 : 0)) <= UInt64(inputBuffer.count) else {
            return nil
        }
        
        if masked {
        
            let mask = [inputBuffer[offset], inputBuffer[offset+1], inputBuffer[offset+2], inputBuffer[offset+3]]
            
            offset = offset + mask.count
            
            let payload = inputBuffer[offset..<(offset + Int(len /* //TODO fix Int64/Int conversion */))]
                .enumerated()
                .map {
                    $0.element ^ mask[Int($0.offset % 4)]
                }
            
            inputBuffer.removeFirst(offset+Int(len))
            
            return Frame(opcode: opcode, payload: payload)
            
        } else {
            
            let payload = [UInt8](inputBuffer[offset..<(offset + Int(len /* //TODO fix Int64/Int conversion */))])
            
            inputBuffer.removeFirst(offset+Int(len))
            
            return Frame(opcode: opcode, payload: payload)
        }
    }
    
    private static func addressForHost(_ host: String) throws -> String {
        guard let info = host.withCString({ gethostbyname($0) }) else {
            throw Err.io("Could not find address for \(host): gethostbyname failed.")
        }
        guard let first = info.pointee.h_addr_list[0] else {
            throw Err.io("Could not find address for \(host): empty list.")
        }
        var buffer = [Int8](repeating: 0, count: 256)
        guard inet_ntop(AF_INET, first, &buffer, socklen_t(buffer.count)) != nil else {
            throw Err.io("Could not find address for \(host): inet_ntop failed \(errno).")
        }
        return String(cString: buffer)
    }
}
