//
//  CardView.swift
//  
//
//  Created by Risha V on 10/19/26.
//

import UIKit

class CardView: UIView {
    let card: SwipeCard
    private let titleLabel = UILabel()
    
    init(card: SwipeCard) {
        self.card = card
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = card.color
        layer.cornerRadius = 28
        layer.masksToBounds = false
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        layer.borderWidth = 1.5
        
        titleLabel.text = card.title
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    // Instantly resets or setups the card back to its messy base placement state
    func applyDefaultUnalignedTransform() {
        let rotation = CGAffineTransform(rotationAngle: card.randomRotation * .pi / 180)
        let translation = CGAffineTransform(translationX: card.randomOffsetX, y: card.randomOffsetY)
        self.transform = rotation.concatenating(translation)
    }
}
