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
import UniformTypeIdentifiers

@objc
public class MainWindowController: NSWindowController
{
    @objc private dynamic var url:      URL
    @objc private dynamic var name:     String?
    @objc private dynamic var icon:     NSImage?
    @objc private dynamic var info:     String?
    @objc private dynamic var progress: Progress?
    @objc private dynamic var loading = false
    @objc private dynamic var format  = 0

    private var images: [ URL ] = []

    @IBOutlet private var dropView: DropView?

    private enum ImageFormat: Int
    {
        case tif
        case png
        case jpg
        case bmp
        case gif
    }

    public init( url: URL )
    {
        self.url  = url

        super.init( window: nil )
    }

    public required init?( coder: NSCoder )
    {
        nil
    }

    public override var windowNibName: NSNib.Name?
    {
        "MainWindowController"
    }

    public override func windowDidLoad()
    {
        super.windowDidLoad()
        self.loadImages()

        if let view = self.dropView
        {
            view.onDrop =
            {
                guard self.loading == false
                else
                {
                    NSSound.beep()

                    return
                }

                self.url = $0

                self.loadImages()
            }
        }
    }

    private func showError( message: String, closeWindow: Bool )
    {
        DispatchQueue.main.async
        {
            let alert             = NSAlert()
            alert.messageText     = "Error"
            alert.informativeText = message

            if let window = self.window
            {
                alert.beginSheetModal( for: window )
                {
                    _ in if closeWindow
                    {
                        DispatchQueue.main.async
                        {
                            window.performClose( nil )
                        }
                    }
                }
            }
            else
            {
                alert.runModal()

                if closeWindow
                {
                    DispatchQueue.main.async
                    {
                        self.window?.performClose( nil )
                    }
                }
            }
        }
    }

    private func loadImages()
    {
        self.images        = []
        self.window?.title = "Photo Converter - \( self.url.lastPathComponent )"
        self.name          = self.url.lastPathComponent
        self.icon          = NSWorkspace.shared.icon( forFile: self.url.path( percentEncoded: false ) )
        self.loading       = true
        self.info          = "Loading Images - Please Wait..."

        DispatchQueue.global( qos: .userInitiated ).async
        {
            guard let enumerator = FileManager.default.enumerator( atPath: self.url.path( percentEncoded: false ) )
            else
            {
                self.showError( message: "Cannot read directory: \( self.url.lastPathComponent )", closeWindow: true )

                return
            }

            let files: [ ( url: URL, size: Int64 ) ] = enumerator.compactMap
            {
                enumerator.skipDescendants()

                guard let name = $0 as? String
                else
                {
                    return nil
                }

                let url = self.url.appending( component: name )

                guard let uti = UTType( filenameExtension: url.pathExtension ),
                      uti.conforms( to: .image )
                else
                {
                    return nil
                }

                guard let info = try? url.resourceValues( forKeys: [ .fileSizeKey ] ),
                      let size = info.fileSize,
                      size > 0
                else
                {
                    return nil
                }

                return ( url, Int64( size ) )
            }

            let size = files.reduce( 0 )
            {
                $0 + $1.size
            }

            self.images = files.map
            {
                $0.url
            }

            DispatchQueue.main.async
            {
                guard files.isEmpty == false
                else
                {
                    self.showError( message: "The selected directory doesn't contain any image.", closeWindow: true )

                    return
                }

                self.loading = false
                self.info    = "\( files.count ) images - \( BytesToString.string( from: size ) )"
            }
        }
    }

    @IBAction
    private func convert( _ sender: Any? )
    {
        guard let window = self.window,
              let format = ImageFormat( rawValue: self.format )
        else
        {
            NSSound.beep()

            return
        }

        let panel                     = NSOpenPanel()
        panel.canChooseFiles          = false
        panel.canChooseDirectories    = true
        panel.canCreateDirectories    = true
        panel.allowsMultipleSelection = false

        panel.beginSheetModal( for: window )
        {
            guard $0 == .OK, let url = panel.url
            else
            {
                return
            }

            self.convert( to: url, format: format )
        }
    }

    private func convert( to url: URL, format: ImageFormat )
    {
        let info      = self.info
        self.loading  = true
        self.info     = "Converting Images - Please Wait..."
        self.progress = Progress( maxValue: self.images.count )

        DispatchQueue.global( qos: .default ).async
        {
            let ext = switch format
            {
                case .tif: "tif"
                case .png: "png"
                case .jpg: "jpg"
                case .bmp: "bmp"
                case .gif: "gif"
            }

            let images: [ ( source: URL, destination: URL ) ] = self.images.map
            {
                let name = $0.deletingPathExtension().appendingPathExtension( ext ).lastPathComponent

                return ( $0, url.appending( component: name ) )
            }

            let operations = images.map
            {
                image in

                let operation = BlockOperation
                {
                    self.convertImage( url: image.source, to: image.destination, format: format )

                    DispatchQueue.main.async
                    {
                        guard let progress = self.progress
                        else
                        {
                            return
                        }

                        progress.value += 1
                        self.info       = "Converted \( progress.value ) of \( images.count ) images..."
                    }
                }

                operation.qualityOfService = .userInteractive

                return operation
            }

            let queue                         = OperationQueue()
            queue.qualityOfService            = .userInteractive
            queue.maxConcurrentOperationCount = 20

            queue.addOperations( operations, waitUntilFinished: true )

            DispatchQueue.main.async
            {
                self.progress = nil
                self.loading  = false
                self.info     = info
            }
        }
    }

    private func convertImage( url: URL, to destination: URL, format: ImageFormat )
    {
        do
        {
            try autoreleasepool
            {
                let data = try Data( contentsOf: url )

                guard let image = NSImage( data: data )?.cgImage( forProposedRect: nil, context: nil, hints: [ : ] )
                else
                {
                    throw RuntimeError( message: "Cannot read image: \( url.lastPathComponent )" )
                }

                let type = switch format
                {
                    case .tif: UTType.tiff
                    case .png: UTType.png
                    case .jpg: UTType.jpeg
                    case .bmp: UTType.bmp
                    case .gif: UTType.gif
                }

                guard let writer = CGImageDestinationCreateWithURL( destination as CFURL, type.identifier as CFString, 1, nil )
                else
                {
                    throw RuntimeError( message: "Cannot prepare image for writing: \( url.lastPathComponent )" )
                }

                CGImageDestinationAddImage( writer, image, nil )

                if CGImageDestinationFinalize( writer ) == false
                {
                    throw RuntimeError( message: "Cannot write image: \( destination.lastPathComponent )" )
                }
            }
        }
        catch
        {
            self.showError( message: error.localizedDescription, closeWindow: false )
        }
    }
}
