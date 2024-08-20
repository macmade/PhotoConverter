/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2023, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Cocoa

@objc
public class DropView: NSView
{
    public var onDrop: ( ( URL ) -> Void )?

    public override init( frame: NSRect )
    {
        super.init( frame: frame )
        self.registerForDraggedTypes( [ .fileURL ] )
    }

    public required init?( coder: NSCoder )
    {
        super.init( coder: coder )
        self.registerForDraggedTypes( [ .fileURL ] )
    }

    public override func draggingEntered( _ sender: any NSDraggingInfo ) -> NSDragOperation
    {
        var isDir = ObjCBool( false )

        guard let url = sender.draggingPasteboard.readObjects( forClasses: [ NSURL.self ] )?.first as? URL,
              FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ),
              isDir.boolValue
        else
        {
            return []
        }

        return .copy
    }

    public override func performDragOperation( _ sender: any NSDraggingInfo ) -> Bool
    {
        var isDir = ObjCBool( false )

        guard let action = self.onDrop,
              let url    = sender.draggingPasteboard.readObjects( forClasses: [ NSURL.self ] )?.first as? URL,
              FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ),
              isDir.boolValue
        else
        {
            return false
        }

        action( url )

        return true
    }
}
