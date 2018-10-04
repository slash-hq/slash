//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation


struct TextSpan: ExpressibleByStringLiteral {
    
    let text: String
    
    let textColor: Int
    
    let backgroundColor: Int
    
    init(stringLiteral value: String) {
        self.text = value
        self.textColor = R.color.defaulTextColor
        self.backgroundColor = R.color.defaultBgColor
    }
    
    init(extendedGraphemeClusterLiteral value: String) {
        self.text = value
        self.textColor = R.color.defaulTextColor
        self.backgroundColor = R.color.defaultBgColor
    }
    
    init(unicodeScalarLiteral value: String) {
        self.text = value
        self.textColor = R.color.defaulTextColor
        self.backgroundColor = R.color.defaultBgColor
    }
    
    init(_ text: String, withColor: Int = R.color.defaulTextColor, withBackground: Int = R.color.defaultBgColor) {
        self.text = text
        self.textColor = withColor
        self.backgroundColor = withBackground
    }
}

class TextLayout {
    
    let canvas = TerminalCanvas()
    
    func layout(_ spans: [TextSpan], alignToWidth width: Int, highlightColor: Int? = nil) -> [[UInt8]] {
        
        canvas.clear()
        
        var counter = 0
        var lines = [[UInt8]]()
        
        for span in spans {
            
            canvas.background(highlightColor ?? span.backgroundColor)
            canvas.color(span.textColor)
            
            for character in span.text {
                if character == "\n" {
                    canvas.text(String(repeating: " ", count: width - counter))
                    counter = 0
                    lines.append(canvas.buffer)
                    canvas.clear()
                    canvas.background(highlightColor ?? span.backgroundColor)
                    canvas.color(span.textColor)
                } else {
                    canvas.text(String(character))
                    counter = counter + 1
                    if counter == width {
                        counter = 0
                        lines.append(canvas.buffer)
                        canvas.clear()
                        canvas.background(highlightColor ?? span.backgroundColor)
                        canvas.color(span.textColor)
                    }
                }
            
            }
        }
        
        if counter < width {
            canvas.text(String(repeating: " ", count: width - counter))
            lines.append(canvas.buffer)
        }
        
        return lines
    }
    
}
