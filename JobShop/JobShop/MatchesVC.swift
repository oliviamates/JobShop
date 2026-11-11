//
//  MatchesVC.swift
//  JobShop
//
//  "Your Matches!" screen: header, search + filter, dropdown, swipeable card stack.
//  Uses Theme, JobCard and CardView from CardView.swift.
//  Jobs are loaded from the Jobicy API via JobService.swift and shown 20 at a time.
//  Present it with e.g. window.rootViewController = MatchesVC()
//
import UIKit
import UserNotifications
import EventKit
import EventKitUI
import FirebaseFirestore
import FirebaseAuth

class MatchesVC: UIViewController, EKEventEditViewDelegate {
    let eventStore = EKEventStore()
    
    /// The live deck (what's on screen). Last element is the top card.
    private var cardsData: [JobCard] = []

    /// Every card that has been dealt into the deck so far (across batches).
    /// Used to bring a job back if it's removed from the Saved screen.
    private var allCards: [JobCard] = []

    /// Everything the API returned. The deck is fed from this 20 at a time.
    private var pool: [JobCard] = []
    private var poolIndex = 0
    private let batchSize = 5

    /// Jobs the user swiped left on. They never come back (until the app relaunches).
    private var dismissedKeys: Set<String> = []

    /// True while a swipe-off animation is running, so Firestore updates don't rebuild the deck mid-animation.
    private var isSwiping = false

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
        
        // Saved jobs load asynchronously from Firestore, so rebuild the deck whenever they change.
        NotificationCenter.default.addObserver(self, selector: #selector(savedJobsChanged),
                                               name: .savedJobsChanged, object: nil)
        loadJobs()
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        refreshDeck()
    }

    
    private func fetchUserSkills() async -> [String] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("accounts").document(uid).getDocument()
            return snapshot.data()?["skills"] as? [String] ?? []
        } catch {
            print("Failed to load skills: \(error)")
            return []
        }
    }

    private func loadJobs() {
        emptyLabel.text = "Loading matches..."
        emptyLabel.isHidden = false

        Task { [weak self] in
            guard let self else { return }
            do {
                let skills = await self.fetchUserSkills()
                let jobs = try await JobService.shared.fetchJobs(skills: skills, count: 100)
                // Best matches first, so the top of the deck is the strongest fit.
                self.pool = jobs.sorted { $0.matchPercent > $1.matchPercent }
                self.poolIndex = 0
                self.emptyLabel.text = "You're all caught up!\nCheck back later for new matches."
            } catch {
                print("Failed to load jobs: \(error)")
                self.emptyLabel.text = "Couldn't load jobs.\nCheck your connection and try again."
            }
            self.refreshDeck()
        }
    }

    /// Stable identity for a job (matches how the saved-jobs check compares cards).
    private func key(_ card: JobCard) -> String {
        "\(card.company)|\(card.title)"
    }

    /// Deals the next (up to) 20 jobs from the pool into the deck, skipping saved and dismissed ones.
    @discardableResult
    private func loadNextBatch() -> Bool {
        var batch: [JobCard] = []
        while poolIndex < pool.count && batch.count < batchSize {
            let job = pool[poolIndex]
            poolIndex += 1
            if !store.contains(job) && !dismissedKeys.contains(key(job)) {
                batch.append(job)
            }
        }
        guard !batch.isEmpty else { return false }
        allCards.append(contentsOf: batch)
        cardsData = batch
        return true
    }

    // MARK: Deck refresh

    @objc private func savedJobsChanged() {
        guard !isSwiping else { return }
        refreshDeck()
    }

    /// Removes saved and dismissed jobs from the deck, brings back any unsaved job that's missing
    /// (e.g. one that was removed from the Saved screen), and deals the next batch when the deck is empty.
    private func refreshDeck() {
        cardsData.removeAll { store.contains($0) || dismissedKeys.contains(key($0)) }
        for card in allCards where !store.contains(card)
            && !dismissedKeys.contains(key(card))
            && !cardsData.contains(where: { key($0) == key(card) }) {
            cardsData.insert(card, at: 0)
        }
        if cardsData.isEmpty { loadNextBatch() }
        layoutDeckStack()
        // Refresh heart state in case something was (un)saved on another screen.
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
    
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true, completion: nil)
            
            switch action {
            case .canceled:
                print("User cancelled adding the event.")
            case .saved:
                print("Event was successfully saved to the calendar!")
            case .deleted:
                print("Event was deleted.")
            @unknown default:
                break
            }
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
                    let center = UNUserNotificationCenter.current()
                    let content = UNMutableNotificationContent()
                    content.title = "Job Shop Reminder"
                    content.body = "You have " + String(globalNotifChoice) + " days to apply to " + topCard.card.company
                    content.sound = .default
                    
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: globalNotifChoice, repeats: false)
                    let uuidString = UUID().uuidString
                    let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
                
                    center.add(request) { error in
                        if let error = error {
                            print("Error scheduling notification: \(error.localizedDescription)")
                        }
                    }
            presentEventEditor(topCard.card.company)

        }
    }
    
    func presentEventEditor(_ title: String) {
        let editVC = EKEventEditViewController()
        editVC.eventStore = self.eventStore
        editVC.editViewDelegate = self
        
        let event = EKEvent(eventStore: self.eventStore)
        event.title = "Apply to " + title
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(globalNotifChoice)
        event.isAllDay = true
        event.notes = "Log in to JobShop to continue your application!"
        
        editVC.event = event
        self.present(editVC, animated: true, completion: nil)
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
        isSwiping = true
        targetCard.isUserInteractionEnabled = false

        if directionRight {
            targetCard.setLiked(true)
            store.save(targetCard.card)   // writes to Firestore
        }

        let exitX = directionRight ? view.frame.width + 150 : -view.frame.width - 150
        UIView.animate(withDuration: 0.3, animations: {
            targetCard.transform = CGAffineTransform(translationX: exitX, y: targetCard.transform.ty)
            targetCard.alpha = 0
        }) { [weak self] _ in
            self?.recycleCard(targetCard, dismissed: !directionRight)
        }
    }

    /// Removes the swiped card from the deck for good. Saved cards live on the Saved screen,
    /// skipped cards are dismissed and never reinserted.
    private func recycleCard(_ cardView: CardView, dismissed: Bool) {
        isSwiping = false
        let swipedKey = key(cardView.card)
        if dismissed { dismissedKeys.insert(swipedKey) }
        cardsData.removeAll { key($0) == swipedKey }

        if cardsData.isEmpty {
            refreshDeck()      // deals the next batch of 20, or shows the empty state
        } else {
            layoutDeckStack()
        }
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
