import CoreGraphics

enum WattSpacing {
    // Application surface sizes, never native control/row metrics.
    static let panelWidth: CGFloat = 320
    static let panelHeight: CGFloat = 473
    static let compactPanelHeight: CGFloat = 265
    static let chargingHoldPanelHeight: CGFloat = 279
    static let insufficientChargerPanelHeight: CGFloat = 279
    static let panelComponentsOffHeight: CGFloat = 347
    static let setupPanelHeight: CGFloat = 319
    static let setupPanelErrorHeight: CGFloat = 347
    static let desktopPanelHeight: CGFloat = 335
    static let coachMarkWidth: CGFloat = 260
    static let coachMarkHeight: CGFloat = 136
    static let deferredCoachMarkWidth: CGFloat = 310
    static let deferredCoachMarkHeight: CGFloat = 122
    static let xxs: CGFloat = 3
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let dividerHeight: CGFloat = 0.5
    static let referenceSettingsSectionSpacing: CGFloat = 6
    static let sectionRadius: CGFloat = 12
    static let windowRadius: CGFloat = 12
    static let settingsExcerptWidth: CGFloat = 520
    static let settingsExcerptHeight: CGFloat = 256
    static let settingsWidth: CGFloat = 580
    // Settings content is 838pt, including a 20pt top and bottom inset.
    // The Settings scene sizes its native window from that content area.
    static let settingsContentHeight: CGFloat = 838
    static let onboardingWidth: CGFloat = 480
    static let formRowHeight: CGFloat = 42
    static let buttonHeight: CGFloat = 24
    static let menuBarHeight: CGFloat = 24
}
