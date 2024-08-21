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

@main
public class ApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate
{
    @objc private dynamic var aboutWindowController = AboutWindowController()
    @objc private dynamic var windowControllers     = [ MainWindowController ]()

    private var updater = GitHubUpdater( owner: "macmade", repository: "PhotoConverter" )

    public func applicationDidFinishLaunching( _ notification: Notification )
    {
        self.openDocument( nil )

        DispatchQueue.main.asyncAfter( deadline: .now() + .seconds( 2 ) )
        {
            self.updater?.checkForUpdates()
        }
    }

    public func applicationWillTerminate( _ notification: Notification )
    {}

    public func applicationShouldTerminateAfterLastWindowClosed( _ sender: NSApplication ) -> Bool
    {
        false
    }

    public func applicationSupportsSecureRestorableState( _ app: NSApplication ) -> Bool
    {
        false
    }

    @IBAction
    public func showAboutWindow( _ sender: Any? )
    {
        if self.aboutWindowController.window?.isVisible == false
        {
            self.aboutWindowController.window?.layoutIfNeeded()
            self.aboutWindowController.window?.center()
        }

        self.aboutWindowController.window?.makeKeyAndOrderFront( sender )
    }

    @IBAction
    public func newDocument( _ sender: Any? )
    {
        self.openDocument( sender )
    }

    @IBAction
    public func openDocument( _ sender: Any? )
    {
        let panel                     = NSOpenPanel()
        panel.canChooseFiles          = false
        panel.canChooseDirectories    = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url
        else
        {
            return
        }

        let controller     = MainWindowController( url: url )
        controller.onClose =
        {
            [ weak self ] in self?.windowControllers.removeAll
            {
                $0 === controller
            }
        }

        self.windowControllers.append( controller )
        controller.window?.makeKeyAndOrderFront( sender )
    }

    public func applicationShouldTerminate( _ sender: NSApplication ) -> NSApplication.TerminateReply
    {
        for controller in self.windowControllers
        {
            if controller.windowCanBeClosed() == false
            {
                return .terminateCancel
            }
        }

        return .terminateNow
    }
}
