////
////  MatchesVC.swift
////  
////
////  Created by Risha V on 10/19/26.
////
//import UIKit
//import PlaygroundSupport
//
//class MatchesVC: UIViewController {
//    
//    private var cardsData: [SwipeCard] = [
//        SwipeCard(title: "Card 1", color: .systemRed),
//        SwipeCard(title: "Card 2", color: .systemBlue),
//        SwipeCard(title: "Card 3", color: .systemGreen),
//        SwipeCard(title: "Card 4", color: .systemOrange),
//        SwipeCard(title: "Card 5", color: .systemPurple)
//    ]
//    
//    private var cardViews: [CardView] = []
//    private let containerView = UIView()
//    private let statusLabel = UILabel()
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .systemGroupedBackground
//        
//        setupStatusLabel()
//        setupContainer()
//        layoutDeckStack()
//    }
//    
//    private func setupStatusLabel() {
//        statusLabel.text = "swipe"
//        statusLabel.font = .systemFont(ofSize: 18, weight: .medium)
//        statusLabel.textColor = .secondaryLabel
//        statusLabel.textAlignment = .center
//        statusLabel.translatesAutoresizingMaskIntoConstraints = false
//        
//        view.addSubview(statusLabel)
//        NSLayoutConstraint.activate([
//            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
//            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
//        ])
//    }
//    
//    private func setupContainer() {
//        containerView.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(containerView)
//        
//        NSLayoutConstraint.activate([
//            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
//            containerView.widthAnchor.constraint(equalToConstant: 260),
//            containerView.heightAnchor.constraint(equalToConstant: 260)
//        ])
//    }
//    
//    private func layoutDeckStack() {
//        for cardView in cardViews {
//            cardView.removeFromSuperview()
//        }
//        cardViews.removeAll()
//        
//        for cardData in cardsData {
//            let cardView = CardView(card: cardData)
//            cardView.translatesAutoresizingMaskIntoConstraints = false
//            containerView.addSubview(cardView)
//            
//            NSLayoutConstraint.activate([
//                cardView.topAnchor.constraint(equalTo: containerView.topAnchor),
//                cardView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
//                cardView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
//                cardView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
//            ])
//            
//            cardView.applyDefaultUnalignedTransform()
//            cardViews.append(cardView)
//        }
//        
//        setupTopCardGesture()
//    }
//    
//    private func setupTopCardGesture() {
//        guard let topCard = cardViews.last else { return }
//        
//        topCard.gestureRecognizers?.forEach { topCard.removeGestureRecognizer($0) }
//        
//        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
//        topCard.addGestureRecognizer(panGesture)
//    }
//    
//    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
//        guard let targetCard = gesture.view as? CardView else { return }
//        
//        let translation = gesture.translation(in: containerView)
//        
//        switch gesture.state {
//        case .changed:
//            let rotationStrength = min(translation.x / 300, 1.0)
//            let rotationAngle = (CGFloat.pi / 8) * rotationStrength
//            
//            let transformTranslation = CGAffineTransform(translationX: translation.x, y: translation.y)
//            let transformRotation = CGAffineTransform(rotationAngle: rotationAngle)
//            targetCard.transform = transformRotation.concatenating(transformTranslation)
//            
//        case .ended:
//            let swipeThreshold: CGFloat = 130
//            
//            if translation.x > swipeThreshold {
//                animateSwipeOffScreen(targetCard: targetCard, directionRight: true)
//            } else if translation.x < -swipeThreshold {
//                animateSwipeOffScreen(targetCard: targetCard, directionRight: false)
//            } else {
//                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.8, options: .allowUserInteraction, animations: {
//                    targetCard.applyDefaultUnalignedTransform()
//                }, completion: nil)
//            }
//        default:
//            break
//        }
//    }
//    
//    private func animateSwipeOffScreen(targetCard: CardView, directionRight: Bool) {
//        let screenExitWidth = directionRight ? view.frame.width + 150 : -view.frame.width - 150
//        statusLabel.text = directionRight ? "Swiped RIGHT 👉" : "Swiped LEFT 👈"
//        
//        UIView.animate(withDuration: 0.3, animations: {
//            targetCard.transform = CGAffineTransform(translationX: screenExitWidth, y: targetCard.transform.ty)
//            targetCard.alpha = 0
//        }) { [weak self] _ in
//            self?.recycleCard(targetCard)
//        }
//    }
//    
//    private func recycleCard(_ cardView: CardView) {
//        guard let index = cardViews.firstIndex(of: cardView) else { return }
//        cardViews.remove(at: index)
//        cardView.removeFromSuperview()
//        
//
//        let recycledData = cardsData.removeLast()
//        cardsData.insert(recycledData, at: 0)
//        
//        layoutDeckStack()
//    }
//}
//
//
//
