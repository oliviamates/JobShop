import UIKit

struct SwipeCard {
    let title: String
    let color: UIColor
    
    let randomRotation: CGFloat = CGFloat.random(in: -8...8)
    let randomOffsetX: CGFloat = CGFloat.random(in: -12...12)
    let randomOffsetY: CGFloat = CGFloat.random(in: -12...12)
}
