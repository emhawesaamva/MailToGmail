import Cocoa

struct MailtoMessage {
    var to: [String] = []
    var cc: [String] = []
    var bcc: [String] = []
    var subject: String = ""
    var body: String = ""
}

enum MailtoParser {
    static func parse(_ raw: String) -> MailtoMessage? {
        guard let components = URLComponents(string: raw),
              components.scheme?.lowercased() == "mailto" else { return nil }

        var message = MailtoMessage()
        message.to.append(contentsOf: splitAddresses(components.path))

        for item in components.queryItems ?? [] {
            let value = item.value ?? ""
            switch item.name.lowercased() {
            case "to":      message.to.append(contentsOf: splitAddresses(value))
            case "cc":      message.cc.append(contentsOf: splitAddresses(value))
            case "bcc":     message.bcc.append(contentsOf: splitAddresses(value))
            case "subject": message.subject = value
            case "body":    message.body = value
            default: break   // ignore other RFC 6068 hfields (in-reply-to, etc.)
            }
        }
        return message
    }

    /// Mail clients mix commas and semicolons as address separators; normalize
    /// both and drop empty/whitespace-only entries (handles trailing commas,
    /// "mailto:,a@b.com", etc.).
    private static func splitAddresses(_ raw: String) -> [String] {
        raw.split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

enum GmailComposeURLBuilder {
    static func url(for message: MailtoMessage) -> URL? {
        var components = URLComponents(string: "https://mail.google.com/mail/")!
        var items = [
            URLQueryItem(name: "view", value: "cm"),
            URLQueryItem(name: "fs", value: "1"),
        ]
        func addIfPresent(_ name: String, _ addresses: [String]) {
            guard !addresses.isEmpty else { return }
            items.append(URLQueryItem(name: name, value: addresses.joined(separator: ",")))
        }
        addIfPresent("to", message.to)
        addIfPresent("cc", message.cc)
        addIfPresent("bcc", message.bcc)
        if !message.subject.isEmpty { items.append(URLQueryItem(name: "su", value: message.subject)) }
        if !message.body.isEmpty    { items.append(URLQueryItem(name: "body", value: message.body)) }
        components.queryItems = items
        return components.url
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var handledURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Must register here, not in applicationDidFinishLaunching: when Launch
        // Services launches this app specifically to deliver a mailto GetURL
        // event, the event can arrive before applicationDidFinishLaunching fires.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // If no GetURL event arrives shortly after launch, this wasn't opened
        // via a mailto: link (e.g. an accidental double-click) — explain
        // ourselves instead of sitting invisibly as an orphaned process.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.handledURL else { return }
            self.explainDirectLaunchAndQuit()
        }
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        handledURL = true
        guard let raw = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let message = MailtoParser.parse(raw),
              let gmailURL = GmailComposeURLBuilder.url(for: message) else {
            NSLog("MailToGmail: could not parse mailto URL")
            NSApp.terminate(nil)
            return
        }
        // Terminate inside the open() completion handler, not right after
        // calling it, so the process can't exit before Launch Services has
        // actually handled the request.
        NSWorkspace.shared.open(gmailURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { NSLog("MailToGmail: failed to open Gmail compose URL: \(error)") }
            NSApp.terminate(nil)
        }
    }

    private func explainDirectLaunchAndQuit() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "MailToGmail"
        alert.informativeText = "This is a background helper that redirects mailto: links to Gmail's web compose window. To use it, open the Mail app, then open the \"Mail\" menu and choose Settings. Click General and set Default Email Reader to MailToGmail. It isn't meant to be opened directly otherwise."
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
