//
//  MatchesVC.swift
//  JobShop
//
//  "Your Matches!" screen: header, search + filter, dropdown, swipeable card stack.
//  Uses Theme, JobCard and CardView from CardView.swift.
//  Present it with e.g. window.rootViewController = MatchesVC()
//
import UIKit


class MatchesVC: UIViewController {

    
    private var cardsData: [JobCard] = [
        JobCard(company: "Google", title: "Software Engineer", location: "San Francisco, CA",
                description: "Software Engineers at Google need to build scalable systems, collaborate with cross-functional teams, and ship products used by billions.",
                matchPercent: 30, keywords: ["Java", "Python", "JavaScript", "iOS Development"],
                extraKeywords: 10, salary: "$109000 - $150000 annually",
                applyURL: URL(string: "https://careers.google.com")),
        JobCard(company: "Apple", title: "iOS Engineer", location: "Cupertino, CA",
                description: "Build delightful experiences across Apple platforms using Swift and UIKit.",
                matchPercent: 62, keywords: ["Swift", "UIKit", "Xcode", "iOS Development"],
                extraKeywords: 6, salary: "$120000 - $165000 annually",
                applyURL: URL(string: "https://jobs.apple.com")),
        JobCard(company: "Meta", title: "Frontend Engineer", location: "Menlo Park, CA",
                description: "Create fast, accessible interfaces for products used around the world.",
                matchPercent: 48, keywords: ["JavaScript", "React", "CSS", "GraphQL"],
                extraKeywords: 8, salary: "$115000 - $155000 annually",
                applyURL: URL(string: "https://www.metacareers.com")),
        JobCard(company: "Netflix", title: "Backend Engineer", location: "Los Gatos, CA",
                description: "Design services that stream to hundreds of millions of members.",
                matchPercent: 55, keywords: ["Java", "AWS", "Kafka", "Python"],
                extraKeywords: 7, salary: "$130000 - $180000 annually",
                applyURL: URL(string: "https://jobs.netflix.com")),
        JobCard(company: "Spotify", title: "Mobile Engineer", location: "New York, NY",
                description: "Ship features that connect listeners and creators on iOS and Android.",
                matchPercent: 71, keywords: ["Swift", "Kotlin", "Python", "iOS Development"],
                extraKeywords: 5, salary: "$110000 - $150000 annually",
                applyURL: URL(string: "https://www.lifeatspotify.com"))
    ]

    private let store = SavedJobsStore.shared
    private var cardViews: [CardView] = []
    private let containerView = UIView()
    @IBOutlet weak var menuButton: UIBarButtonItem?
    
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel?
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Theme.background
        if let menuButton {
                menuButton.menu = makeNavMenu()              // storyboard button
        } else {
            navigationItem.rightBarButtonItem = makeMenuBarButtonItem()   // created in code
        }
        ensureTitleAndSearchBarExist()
        setupFilterMenu()
        setupContainer()
        cardsData.removeAll { store.contains($0) }
        layoutDeckStack()
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cardsData.removeAll { store.contains($0) }
        layoutDeckStack()
        // Refresh heart state in case something was (un)saved on another screen.
        navigationController?.setNavigationBarHidden(false, animated: animated)
        for cardView in cardViews { cardView.setLiked(store.contains(cardView.card)) }
    }

    private func ensureTitleAndSearchBarExist() {
        if titleLabel == nil {
            let label = UILabel()
            label.text = "Your Matches!"
            label.font = .systemFont(ofSize: 28, weight: .bold)
            label.textColor = Theme.green
            label.translatesAutoresizingMaskIntoConstraints = false
            
            view.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36)
            ])
            
            self.titleLabel = label
        }
        
        if searchBar == nil {
            let bar = UISearchBar()
            bar.placeholder = "Search jobs..."
            bar.searchBarStyle = .minimal
            bar.translatesAutoresizingMaskIntoConstraints = false
            
            view.addSubview(bar)
            
            // Anchor it safely below the titleLabel we verified/created above
            guard let titleBottomAnchor = titleLabel?.bottomAnchor else { return }
            
            NSLayoutConstraint.activate([
                bar.topAnchor.constraint(equalTo: titleBottomAnchor, constant: 10),
                bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28), // padding for search borders
                bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
                bar.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            self.searchBar = bar
        }
    }


    private func setupFilterMenu() {
        func item(_ title: String, locked: Bool = false) -> UIAction {
            UIAction(title: title,
                     image: locked ? UIImage(systemName: "lock") : nil,
                     attributes: locked ? .disabled : []) { _ in
            }
        }
        let filterMenu = UIMenu(children: [
                item("Job Type:"), item("Location:"), item("Industry:"),
                item("Pay Range:", locked: true), item("Recency:", locked: true), item("Job Modal:", locked: true)
            ])

        if let filterButton = filterButton {
            filterButton.menu = filterMenu
            filterButton.showsMenuAsPrimaryAction = true
        } else {
            let codeFilterButton = UIButton(type: .system)
            codeFilterButton.setTitle("Filter ", for: .normal)
            codeFilterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
            codeFilterButton.menu = filterMenu
            codeFilterButton.showsMenuAsPrimaryAction = true
            
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: codeFilterButton)
        }
    }


    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Fallback anchor if searchBar is nil
        let topAnchor = searchBar?.bottomAnchor ?? view.safeAreaLayoutGuide.topAnchor
        let topConstant: CGFloat = searchBar != nil ? 60 : 120
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: topConstant),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1.1)
        ])
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }

    private func layoutDeckStack() {
        cardViews.forEach { $0.removeFromSuperview() }
        cardViews.removeAll()

        for data in cardsData {
            let cardView = CardView(card: data)
            cardView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(cardView)
            NSLayoutConstraint.activate([
                cardView.topAnchor.constraint(equalTo: containerView.topAnchor),
                cardView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                cardView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                cardView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            cardView.setLiked(store.contains(data))
            cardViews.append(cardView)
        }

        for (i, cardView) in cardViews.enumerated() {
            cardView.applyStackTransform(depth: cardViews.count - 1 - i)
        }
        emptyLabel.isHidden = !cardsData.isEmpty
        setupTopCardGesture()
    }

    private func setupTopCardGesture() {
        guard let topCard = cardViews.last else { return }
        topCard.gestureRecognizers?
            .filter { $0 is UIPanGestureRecognizer }
            .forEach { topCard.removeGestureRecognizer($0) }
        topCard.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:))))

        topCard.onTapped = { [weak self, weak topCard] in
            guard let self, let topCard else { return }
            self.navigationController?.pushViewController(ExpandedJobVC(job: topCard.card), animated: true)
        }

        topCard.onHeartTapped = { [weak self, weak topCard] in
            guard let self, let topCard else { return }
            self.animateSwipeOffScreen(targetCard: topCard, directionRight: true)
        }
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let card = gesture.view as? CardView else { return }
        let t = gesture.translation(in: containerView)
        let v = gesture.velocity(in: containerView)

        switch gesture.state {
        case .changed:
            let strength = max(min(t.x / 300, 1), -1)
            let angle = (CGFloat.pi / 8) * strength
            card.transform = CGAffineTransform(rotationAngle: angle)
                .concatenating(CGAffineTransform(translationX: t.x, y: t.y))
        case .ended:
            let distance: CGFloat = 100
            let flick: CGFloat = 800
            if t.x > distance || v.x > flick {
                animateSwipeOffScreen(targetCard: card, directionRight: true)
            } else if t.x < -distance || v.x < -flick {
                animateSwipeOffScreen(targetCard: card, directionRight: false)
            } else {
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.65,
                               initialSpringVelocity: 0.8, options: .allowUserInteraction) {
                    card.applyStackTransform(depth: 0)
                }
            }
        default:
            break
        }
    }

    private func animateSwipeOffScreen(targetCard: CardView, directionRight: Bool) {
        targetCard.isUserInteractionEnabled = false

        if directionRight {
            targetCard.setLiked(true)
            store.save(targetCard.card)
        }

        let exitX = directionRight ? view.frame.width + 150 : -view.frame.width - 150
        UIView.animate(withDuration: 0.3, animations: {
            targetCard.transform = CGAffineTransform(translationX: exitX, y: targetCard.transform.ty)
            targetCard.alpha = 0
        }) { [weak self] _ in
            self?.recycleCard(targetCard)
        }
    }

    private func recycleCard(_ cardView: CardView) {
        guard cardViews.contains(cardView) else { return }
        let swiped = cardsData.removeLast()

        if store.contains(swiped) {
        } else {
            cardsData.insert(swiped, at: 0)   // skipped goes to the back for now
        }
        layoutDeckStack()
    }
    
    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "You're all caught up!\nCheck back later for new matches."
        l.numberOfLines = 0
        l.textAlignment = .center
        l.textColor = .darkGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
}
