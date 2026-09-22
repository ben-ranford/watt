<!--
{
  "availability" : [
    "macOS: -"
  ],
  "documentType" : "symbol",
  "framework" : "AppKit",
  "identifier" : "/documentation/AppKit/NSWorkspace/didWakeNotification",
  "metadataVersion" : "0.1.0",
  "role" : "Type Property",
  "symbol" : {
    "kind" : "Type Property",
    "modules" : [
      "AppKit"
    ],
    "preciseIdentifier" : "c:@NSWorkspaceDidWakeNotification"
  },
  "title" : "didWakeNotification"
}
-->

# didWakeNotification

A notification that the workspace posts when the device wakes from sleep.

```
class let didWakeNotification: NSNotification.Name
```

## Discussion

The notification object is the shared `NSWorkspace` instance. The notification doesn’t contain a `userInfo` dictionary.

> Important:
> To receive this notification, use ``doc://com.apple.appkit/documentation/AppKit/NSWorkspace/notificationCenter`` to register for it. If you use a different notification center to register, you won’t receive the notification.

To observe this notification using Swift concurrency, use [`NSWorkspace.DidWakeMessage`](/documentation/AppKit/NSWorkspace/DidWakeMessage).

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)