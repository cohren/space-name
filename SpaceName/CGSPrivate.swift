import CoreGraphics

// Private SkyLight/CoreGraphics APIs. There is no public way to identify the
// current Space; every Space utility (yabai, WhichSpace, Spaceman) uses these.

typealias CGSConnectionID = Int32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

/// One dictionary per display: "Display Identifier", "Current Space", "Spaces".
@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray?
