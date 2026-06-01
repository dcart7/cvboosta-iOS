import SwiftUI

enum BoostaMotion {
    static let snap = Animation.spring(response: 0.32, dampingFraction: 0.84)
    static let smooth = Animation.spring(response: 0.48, dampingFraction: 0.9)
    static let slowReveal = Animation.spring(response: 0.7, dampingFraction: 0.88)
}
