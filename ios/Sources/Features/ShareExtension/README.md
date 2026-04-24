# Share Extension (Phase 4)

Adds a “Ask BA6” action to the iOS share sheet so any highlighted text,
URL, or image anywhere in the system can be piped into the main app.

Not implemented yet — requires a second Xcode target of type
`Share Extension`. Steps when we get there:

1. Add a new target `Ba6AiShare` of type **Share Extension** in `project.yml`.
2. Declare activation rules in the extension's `Info.plist`
   (`NSExtensionAttributes.NSExtensionActivationRule` → text / URL / image).
3. Read `NSExtensionContext.inputItems`, serialise to a payload, and post
   it into an App Group container shared with the main app.
4. On next app launch (or via a background URL scheme), drain the App
   Group queue into a new chat turn.

The extension *cannot* load the MLX model itself — memory pressure in
extensions is too tight. It only hands work off to the main app.
